#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define ASYNC_IOD ((object)(ROOT "/gamelib/single/daemons/async_iod.pike"))

#define AUTOFIGHT_DAILY_SECONDS (8*60*60)
#define AUTOFIGHT_VIP_BONUS_SECONDS (2*60*60)
#define AUTOFIGHT_MAX_VIP_LEVEL 8
#define AUTOFIGHT_ROUTE_COOLDOWN 8
#define AUTOFIGHT_ROAM_NO_TARGET_TICKS 3
#define AUTOFIGHT_ROAM_BACKTRACK_TICKS 6
#define AUTOFIGHT_LOOT_RETRY_SECONDS 10
#define AUTOFIGHT_CONFIG_VERSION 9
#define AUTOFIGHT_SKILL_QUEUE_SIZE 3
#define AUTOFIGHT_SMART_SKILL_REFRESH_SECONDS 30
#define AUTOFIGHT_CLEANUP_NAME_LIMIT 20
#define AUTOFIGHT_SCAN_MAX_OBJECTS 128
#define AUTOFIGHT_SERVER_TICK_SECONDS 1
#define AUTOFIGHT_SERVER_SCAN_BUDGET 128
#define AUTOFIGHT_SERVER_NORMAL_DISPATCH_BUDGET 16
#define AUTOFIGHT_SERVER_PRESSURE_DISPATCH_BUDGET 8
#define AUTOFIGHT_SERVER_SEVERE_DISPATCH_BUDGET 4
#define AUTOFIGHT_SERVER_PRESSURE_PENDING 32
#define AUTOFIGHT_SERVER_SEVERE_PENDING 64
#define AUTOFIGHT_SERVER_INFLIGHT_TIMEOUT 30
#define AUTOFIGHT_FINAL_VIEW_SECONDS 30
#define AUTOFIGHT_VIEW_MAX_BYTES (512*1024)
#define AUTOFIGHT_PUBLIC_ROOM_CAPACITY 4
#define AUTOFIGHT_DYNAMIC_ROOM_CAPACITY 1
#define AUTOFIGHT_OVERFLOW_ROOM_CAPACITY 4
#define AUTOFIGHT_OVERFLOW_MAX_PER_POOL 8
#define AUTOFIGHT_OVERFLOW_GLOBAL_LIMIT 64
#define AUTOFIGHT_OVERFLOW_IDLE_SECONDS (10*60)
#define AUTOFIGHT_OVERFLOW_CLEANUP_SECONDS 60

private array(string) auto_buff_kinds = ({
	"attri_base",
	"attri_attack",
	"attri_defend",
	"attri_vice",
	"attri_luck",
	"attri_honer",
	"attri_exp",
	// 商城特药（每日次数受 query_max_yao() 限制），玩家显式开启挂机嗑药时一并代吃。
	"te_base",
	"te_attack",
	"te_defend",
	"te_vice",
	"te_luck",
	"te_honer",
	"te_exp",
});

private int autofight_scan_count;
private int autofight_scan_deferred_objects;
private mapping(string:array(mapping(string:mixed))) autofight_overflow_rooms=([]);
private int autofight_overflow_room_count;
private int autofight_overflow_created;
private int autofight_overflow_destroyed;
private int autofight_overflow_limit_fallbacks;
private int autofight_overflow_cleanup_scheduled;
private int autofight_training_reroutes;
private int autofight_pressure_refills;
// 浏览器只读取画面；一个全局调度器把原有 flushview 命令交给 HTTP
// 世界队列。玩家/战斗对象绝不进入工作线程。
private mapping(string:int) server_autofight_epochs = ([]);
private mapping(string:int) server_autofight_inflight = ([]);
private mapping(string:int) server_autofight_inflight_started = ([]);
private mapping(string:mapping(string:mixed)) server_autofight_views = ([]);
// 计时租约只保存在当前 Pike 进程内。重启或人物对象重建后，第一次
// flushview 只重新锚定时间，不能把停服/离线间隔当成有效挂机扣除。
private mapping(string:object) server_autofight_charge_owners = ([]);
// Failed-loot retry targets are live process objects. They must never enter the
// player's serialised data_tmp mapping or cross a map-worker boundary.
private mapping(string:mapping(string:mixed)) autofight_failed_loot_runtime = ([]);
private mapping(string:int) server_autofight_ordered = ([]);
private array(string) server_autofight_order = ({});
private int server_autofight_cursor;
private int next_server_autofight_epoch;
private int next_server_autofight_request_id;
private int next_server_autofight_view_sequence;
private string server_autofight_view_generation;
private int server_autofight_tick_scheduled;
private int server_autofight_ticks;
private int server_autofight_enqueued;
private int server_autofight_coalesced;
private int server_autofight_rejected;
private int server_autofight_oversized_views;
private int server_autofight_cleanup_scheduled;
private int server_autofight_cycle_remaining;
private int server_autofight_inflight_timeouts;
private int server_autofight_inflight_backlog_protected;
private int server_autofight_last_dispatch_budget =
	AUTOFIGHT_SERVER_NORMAL_DISPATCH_BUDGET;
private int server_autofight_last_world_pending;
private int server_autofight_last_pressure_level;
private int server_autofight_pressure_evaluations;
private int server_autofight_severe_pressure_evaluations;
private int server_autofight_throttled_batches;

private string normalize_server_autofight_userid(string userid)
{
	// 与 HTTP 虚拟连接池使用同一精确键，兼容历史大写账号且不串号。
	return String.trim_all_whites(userid || "");
}

int query_server_autofight_dispatch_budget_for(int world_pending,
	int capacity_warning)
{
	if(world_pending>=AUTOFIGHT_SERVER_SEVERE_PENDING)
		return AUTOFIGHT_SERVER_SEVERE_DISPATCH_BUDGET;
	if(world_pending>=AUTOFIGHT_SERVER_PRESSURE_PENDING ||
	   capacity_warning)
		return AUTOFIGHT_SERVER_PRESSURE_DISPATCH_BUDGET;
	return AUTOFIGHT_SERVER_NORMAL_DISPATCH_BUDGET;
}

private int query_server_autofight_dispatch_budget()
{
	int budget;
	int pressure_level = 0;
	int world_pending = 0;
	if(HTTP_APID &&
	   functionp(HTTP_APID->query_world_pending_command_count))
		world_pending = HTTP_APID->query_world_pending_command_count();
	budget = query_server_autofight_dispatch_budget_for(world_pending,
		query_runtime_capacity_warning());
	if(budget==AUTOFIGHT_SERVER_SEVERE_DISPATCH_BUDGET)
		pressure_level = 2;
	else if(budget==AUTOFIGHT_SERVER_PRESSURE_DISPATCH_BUDGET)
		pressure_level = 1;
	server_autofight_last_dispatch_budget = budget;
	server_autofight_last_world_pending = world_pending;
	server_autofight_last_pressure_level = pressure_level;
	if(pressure_level>0)
		server_autofight_pressure_evaluations++;
	if(pressure_level>1)
		server_autofight_severe_pressure_evaluations++;
	return budget;
}

private void schedule_server_autofight_tick()
{
	if(server_autofight_tick_scheduled ||
	   sizeof(server_autofight_epochs)==0)
		return;
	server_autofight_tick_scheduled = 1;
	call_out(run_server_autofight_tick,AUTOFIGHT_SERVER_TICK_SECONDS);
}

private void compact_server_autofight_order()
{
	array(string) compacted = ({});
	mapping(string:int) ordered = ([]);
	foreach(server_autofight_order,string userid){
		if(!server_autofight_epochs[userid] || ordered[userid])
			continue;
		compacted += ({userid});
		ordered[userid] = 1;
	}
	server_autofight_order = compacted;
	server_autofight_ordered = ordered;
	if(server_autofight_cursor>=sizeof(server_autofight_order))
		server_autofight_cursor = 0;
}

private void reset_server_autofight_order_if_idle()
{
	if(sizeof(server_autofight_epochs))
		return;
	server_autofight_order = ({});
	server_autofight_ordered = ([]);
	server_autofight_cursor = 0;
	server_autofight_cycle_remaining = 0;
}

private void schedule_server_autofight_view_cleanup()
{
	if(server_autofight_cleanup_scheduled)
		return;
	server_autofight_cleanup_scheduled = 1;
	call_out(cleanup_server_autofight_views,AUTOFIGHT_FINAL_VIEW_SECONDS);
}

private void cleanup_server_autofight_views()
{
	int now = time();
	int inactive_remaining = 0;
	server_autofight_cleanup_scheduled = 0;
	foreach(indices(server_autofight_views),string userid){
		mapping snapshot = server_autofight_views[userid];
		if(!snapshot)
			continue;
		if(!(int)snapshot["active"] &&
		   now-(int)snapshot["updated_at"]>=AUTOFIGHT_FINAL_VIEW_SECONDS)
			m_delete(server_autofight_views,userid);
		else if(!(int)snapshot["active"])
			inactive_remaining = 1;
	}
	if(inactive_remaining)
		schedule_server_autofight_view_cleanup();
}

private void deactivate_server_autofight_view(string userid)
{
	mapping snapshot = server_autofight_views[userid];
	if(!snapshot)
		return;
	snapshot["active"] = 0;
	snapshot["updated_at"] = time();
	schedule_server_autofight_view_cleanup();
}

private void record_server_autofight_view(string userid,string output,
	int epoch,int active)
{
	int sequence;
	if(userid=="" || !output || output=="" || has_prefix(output,"错误:"))
		return;
	if(sizeof(output)>AUTOFIGHT_VIEW_MAX_BYTES){
		server_autofight_oversized_views++;
		output = "挂机画面输出过大，战斗仍在服务端继续；请回到前台手动查看。\n";
	}
	next_server_autofight_view_sequence++;
	if(next_server_autofight_view_sequence<=0)
		next_server_autofight_view_sequence = 1;
	sequence = next_server_autofight_view_sequence;
	server_autofight_views[userid] = ([
		"output":output,
		"sequence":sequence,
		"updated_at":time(),
		"epoch":epoch,
		"active":active,
	]);
	if(!active)
		schedule_server_autofight_view_cleanup();
}

private void finish_server_autofight_tick(string output,string userid,
	int epoch,int request_id)
{
	object me;
	int active;
	int matched;
	userid = normalize_server_autofight_userid(userid);
	matched = server_autofight_epochs[userid]==epoch &&
		server_autofight_inflight[userid]==request_id;
	if(matched){
		m_delete(server_autofight_inflight,userid);
		m_delete(server_autofight_inflight_started,userid);
	}
	// stop_autofight 可能在本次 flushview 内发生。只要确实是当前在途
	// 命令，仍保留最后一帧；旧 epoch 的迟到回调则必须丢弃。
	if(!matched)
		return;
	me = HTTP_APID->get_player_from_connection(userid,0);
	active = server_autofight_epochs[userid]==epoch && me &&
		functionp(me->query_autofight) &&
		me->query_autofight()=="enable";
	record_server_autofight_view(userid,output,epoch,active);
	if(!active)
		m_delete(server_autofight_epochs,userid);
	reset_server_autofight_order_if_idle();
}

private void run_server_autofight_tick()
{
	int examined = 0;
	int scheduled = 0;
	int dispatched = 0;
	int dispatch_budget = query_server_autofight_dispatch_budget();
	int queue_backoff = 0;
	int throttle_backoff = 0;
	int total;
	server_autofight_tick_scheduled = 0;
	if(server_autofight_cycle_remaining<=0){
		server_autofight_ticks++;
		if(server_autofight_ticks%60==0 ||
		   sizeof(server_autofight_order)>
		   sizeof(server_autofight_epochs)*2+
		   AUTOFIGHT_SERVER_SCAN_BUDGET)
			compact_server_autofight_order();
		server_autofight_cycle_remaining=sizeof(server_autofight_order);
	}
	total = sizeof(server_autofight_order);
	if(server_autofight_cycle_remaining>total)
		server_autofight_cycle_remaining=total;
	while(examined<total && server_autofight_cycle_remaining>0 &&
	   scheduled<AUTOFIGHT_SERVER_SCAN_BUDGET &&
	   dispatched<dispatch_budget){
		object me;
		string userid;
		int request_id;
		if(server_autofight_cursor>=total)
			server_autofight_cursor = 0;
		userid = server_autofight_order[server_autofight_cursor];
		server_autofight_cursor++;
		examined++;
		server_autofight_cycle_remaining--;
		if(!server_autofight_epochs[userid])
			continue;
		scheduled++;
		int epoch = server_autofight_epochs[userid];
		if(server_autofight_inflight[userid]){
			int inflight_age = time()-
				(int)server_autofight_inflight_started[userid];
			int queued = 0;
			if(inflight_age>=AUTOFIGHT_SERVER_INFLIGHT_TIMEOUT &&
			   HTTP_APID &&
			   functionp(HTTP_APID->query_world_user_queue_size))
				queued = HTTP_APID->query_world_user_queue_size(userid);
			if(inflight_age<AUTOFIGHT_SERVER_INFLIGHT_TIMEOUT || queued>0){
				if(inflight_age>=AUTOFIGHT_SERVER_INFLIGHT_TIMEOUT &&
				   queued>0)
					server_autofight_inflight_backlog_protected++;
				server_autofight_coalesced++;
				continue;
			}
			m_delete(server_autofight_inflight,userid);
			m_delete(server_autofight_inflight_started,userid);
			server_autofight_inflight_timeouts++;
		}
		me = HTTP_APID->get_player_from_connection(userid,0);
		if(!me || !functionp(me->query_autofight) ||
		   me->query_autofight()!="enable"){
			m_delete(server_autofight_epochs,userid);
			m_delete(server_autofight_inflight,userid);
			m_delete(server_autofight_inflight_started,userid);
			m_delete(server_autofight_charge_owners,userid);
			deactivate_server_autofight_view(userid);
			continue;
		}
		// 旧浏览器每次 flushview 都会刷新虚拟连接时间。服务端接管后也
		// 必须保留这一语义，否则被系统冻结的后台标签会在1-2小时后
		// 被空闲清理误踢；挂机关闭或额度耗尽后此保活自然停止。
		HTTP_APID->update_connection_time(userid);
		next_server_autofight_request_id++;
		if(next_server_autofight_request_id<=0)
			next_server_autofight_request_id=1;
		request_id=next_server_autofight_request_id;
		server_autofight_inflight[userid] = request_id;
		server_autofight_inflight_started[userid] = time();
		if(HTTP_APID->enqueue_world_command(userid,"","flushview",
		   finish_server_autofight_tick,({userid,epoch,request_id}))){
			server_autofight_enqueued++;
			dispatched++;
		}
		else{
			m_delete(server_autofight_inflight,userid);
			m_delete(server_autofight_inflight_started,userid);
			server_autofight_rejected++;
			// 全局世界队列满时保留当前游标和本轮额度。否则每轮都从
			// 同一批用户开始，会让容量之后的后台玩家永久饥饿。
			server_autofight_cursor--;
			if(server_autofight_cursor<0)
				server_autofight_cursor=total-1;
			server_autofight_cycle_remaining++;
			queue_backoff=1;
			break;
		}
	}
	if(dispatched>=dispatch_budget && server_autofight_cycle_remaining>0){
		throttle_backoff=1;
		server_autofight_throttled_batches++;
	}
	if(server_autofight_cycle_remaining>0 &&
	   sizeof(server_autofight_epochs)>0){
		server_autofight_tick_scheduled=1;
		// 扫描分片可在同一秒继续；实际入队达到本秒预算，或世界队列已满
		// 时退避一秒。游标和本轮额度均保留，避免尾部玩家饥饿。
		call_out(run_server_autofight_tick,
			(queue_backoff || throttle_backoff) ? 1 : 0);
	}
	else{
		server_autofight_cycle_remaining=0;
		schedule_server_autofight_tick();
	}
}

void ensure_server_autofight_tick(object me)
{
	string userid;
	int epoch;
	if(!me || !functionp(me->query_name))
		return;
	userid = normalize_server_autofight_userid((string)me->query_name());
	if(userid=="" || server_autofight_epochs[userid])
		return;
	if(!HTTP_APID || !functionp(HTTP_APID->has_virtual_connection) ||
	   !HTTP_APID->has_virtual_connection(userid))
		return;
	next_server_autofight_epoch++;
	if(next_server_autofight_epoch<=0)
		next_server_autofight_epoch = 1;
	epoch = next_server_autofight_epoch;
	server_autofight_epochs[userid] = epoch;
	if(!server_autofight_ordered[userid]){
		server_autofight_ordered[userid] = 1;
		server_autofight_order += ({userid});
	}
	m_delete(server_autofight_inflight,userid);
	m_delete(server_autofight_inflight_started,userid);
	m_delete(server_autofight_views,userid);
	schedule_server_autofight_tick();
}

void cancel_server_autofight_tick(object me)
{
	string userid;
	if(!me || !functionp(me->query_name))
		return;
	userid = normalize_server_autofight_userid((string)me->query_name());
	if(userid=="")
		return;
	m_delete(server_autofight_epochs,userid);
	m_delete(server_autofight_inflight,userid);
	m_delete(server_autofight_inflight_started,userid);
	m_delete(server_autofight_charge_owners,userid);
	deactivate_server_autofight_view(userid);
	clear_failed_loot(me);
	reset_server_autofight_order_if_idle();
}

/** Re-register an enabled player after a fenced map-worker reconstruction. */
int resume_worker_handoff(object me)
{
	string userid;
	if(!me || !functionp(me->query_autofight) ||
	   me->query_autofight()!="enable")
		return 0;
	userid=normalize_server_autofight_userid((string)me->query_name());
	if(userid=="")
		return 0;
	// The source worker unregisters its scheduler during retirement. Re-anchor
	// charging here so transport/load latency is never billed as active play.
	server_autofight_charge_owners[userid]=me;
	me["/tmp/autofight_last_charge"] = time();
	me["/tmp/autofight_no_target_ticks"] = 0;
	me["/tmp/autofight_previous_room"] = "";
	me["/tmp/autofight_resting"] = 0;
	me["/tmp/autofight_rest_started"] = 0;
	clear_failed_loot(me);
	reset_scan_state(me);
	initialize_player(me);
	ensure_server_autofight_tick(me);
	return query_server_autofight_tick_active(me);
}

int query_server_autofight_tick_active(object me)
{
	string userid;
	if(!me || !functionp(me->query_name))
		return 0;
	userid = normalize_server_autofight_userid((string)me->query_name());
	return userid!="" && server_autofight_epochs[userid]>0;
}

mapping(string:mixed) query_server_autofight_view(object me)
{
	string userid;
	mapping(string:mixed) snapshot;
	if(!me || !functionp(me->query_name))
		return ([]);
	userid = normalize_server_autofight_userid((string)me->query_name());
	if(userid=="")
		return ([]);
	snapshot = server_autofight_views[userid];
	if(!snapshot)
		return ([]);
	if(!(int)snapshot["active"] &&
	   time()-(int)snapshot["updated_at"]>AUTOFIGHT_FINAL_VIEW_SECONDS){
		m_delete(server_autofight_views,userid);
		return ([]);
	}
	return copy_value(snapshot);
}

string query_server_autofight_view_generation()
{
	return server_autofight_view_generation;
}

private array(mapping(string:mixed)) smart_training_routes = ({
	([
		"max":2,
		"level":1,
		"name":"初入仙途",
		"human":"congxianzhen/shangshanlu",
		"monst":"minglingzhihai/minglingqianhai",
		"third":"congxianzhen/shangshanlu",
	]),
	([
		"max":5,
		"level":3,
		"name":"村外试炼",
		"human":"congxianzhen/xiaoshouxueyiceng",
		"monst":"shanyaohaiwan/miwusenlin",
		"third":"huanyecun/huanyecun",
	]),
	([
		"max":8,
		"level":6,
		"name":"营地试炼",
		"human":"kunlunshan/piaohuaxi",
		"monst":"kulougang/kuguchalu",
		"third":"liehuoying/liehuonan",
	]),
	([
		"max":10,
		"level":9,
		"name":"迷雾试炼",
		"human":"kunlunshan/pubudongxuesanceng",
		"monst":"mihuandao/nongwusenlin",
		"third":"mihuandao/nongwusenlin",
	]),
	([
		"max":13,
		"level":11,
		"name":"初阶修行",
		"human":"kunlunshan/xiuxian",
		"monst":"jinaodao/qianshakeng",
		"monst_level":10,
		"third":"kunlunshan/xiuxian",
	]),
	([
		"max":16,
		"level":14,
		"name":"炼体修行",
		"human":"kunlunshan/lianshen",
		"monst":"jinaodao/duanmulin",
		"monst_level":15,
		"third":"kunlunshan/lianshen",
	]),
	([
		"max":19,
		"level":17,
		"name":"洞府修行",
		"human":"shierxianjing/taoyuantongjiuceng",
		"monst":"wugongdong/xieduhe",
		"third":"shierxianjing/taoyuantongjiuceng",
	]),
	([
		"max":22,
		"level":20,
		"name":"灵境修行",
		"human":"shierxianjing/taoyuantongshijiuceng",
		"monst":"wugongdong/rongchongfang",
		"third":"shierxianjing/taoyuantongshijiuceng",
	]),
	([
		"max":25,
		"level":23,
		"name":"深洞修行",
		"human":"shierxianjing/magudongshisanceng",
		"monst":"wugongdong/wugongshenyuan",
		"third":"shierxianjing/magudongshisanceng",
	]),
	([
		"max":28,
		"level":26,
		"name":"水阁修行",
		"human":"plshuige/qingyuntai",
		"monst":"plshuige/liexiandao",
		"third":"liangjinghu/yinhuxuanqiao",
	]),
	([
		"max":31,
		"level":29,
		"name":"云海修行",
		"human":"plshuige/mianyunti",
		"monst":"plshuige/yunpulu",
		"third":"liangjinghu/huayaotingyuan15",
	]),
	([
		"max":34,
		"level":32,
		"name":"城外历练",
		"human":"xiqiwaicheng/nanchengqiangjiao",
		"monst":"chaogewaicheng/chaogedongnanlou",
		"third":"muye/xicezhanhao",
	]),
	([
		"max":37,
		"level":35,
		"name":"牧野历练",
		"human":"xiqiwaicheng/huanhuashuitai",
		"monst":"chaogewaicheng/eluanshihetan",
		"third":"muye/guzhandao",
	]),
	([
		"max":40,
		"level":38,
		"name":"战场历练",
		"human":"muye/poyaozhen9",
		"monst":"muye/fuluying9",
		"third":"muye/hexiyandong10",
	]),
	([
		"max":43,
		"level":41,
		"name":"外海历练",
		"human":"waihai/lingyicheng",
		"monst":"waihai/lingyicheng",
		"third":"waihai/lingyicheng",
	]),
	([
		"max":46,
		"level":44,
		"name":"外海深修",
		"human":"waihai/qianhaiguanmucong",
		"monst":"waihai/qianhaiguanmucong",
		"third":"waihai/qianhaiguanmucong",
	]),
	([
		"max":49,
		"level":47,
		"name":"三界进阶",
		"human":"yandigu/xiaoshilu",
		"monst":"fuxishan/fuxidongrukou",
		"third":"huangyuan/yingxielu",
	]),
	([
		"max":52,
		"level":50,
		"name":"流光平原历练",
		"human":"liuguangpingyuan/liuguangchalu",
		"monst":"liuguangpingyuan/liuguangchalu",
		"third":"liuguangpingyuan/liuguangchalu",
	]),
	([
		"max":54,
		"level":53,
		"name":"蓬莱云石历练",
		"human":"plxianjing/dangyunshijie",
		"monst":"plxianjing/dangyunshijie",
		"third":"plxianjing/dangyunshijie",
	]),
	([
		"max":58,
		"level":55,
		"name":"冰幻云台历练",
		"human":"plxianjing/binghuanyuntai",
		"monst":"plxianjing/binghuanyuntai",
		"third":"plxianjing/binghuanyuntai",
	]),
	([
		"max":61,
		"level":60,
		"name":"云野平原历练",
		"human":"penglaihuanjing/yunyepingyuan",
		"monst":"penglaihuanjing/yunyepingyuan",
		"third":"penglaihuanjing/yunyepingyuan",
	]),
	([
		"max":63,
		"level":62,
		"name":"秋霜石路历练",
		"human":"penglaihuanjing/qiushuangshilu",
		"monst":"penglaihuanjing/qiushuangshilu",
		"third":"penglaihuanjing/qiushuangshilu",
	]),
	([
		"max":65,
		"level":64,
		"name":"烈火池塘历练",
		"human":"penglaihuanjing/liehuochitang",
		"monst":"penglaihuanjing/liehuochitang",
		"third":"penglaihuanjing/liehuochitang",
	]),
	([
		"max":67,
		"level":66,
		"name":"昆仑幻境历练",
		"human":"klshuanjingwaicheng/heiheyuan",
		"monst":"klshuanjingwaicheng/heiheyuan",
		"third":"klshuanjingwaicheng/heiheyuan",
	]),
	([
		"max":69,
		"level":68,
		"name":"幻境深处历练",
		"human":"klshuanjingwaicheng/heishandong",
		"monst":"klshuanjingwaicheng/heishandong",
		"third":"klshuanjingwaicheng/heishandong",
	]),
});

// 每条推荐路线配 3-6 个等级等价的公共房间。这里只改变去哪一间房，
// 不改变怪物属性、战斗、经验或掉落公式。
private mapping(string:array(string)) training_route_pools = ([
	"congxianzhen/shangshanlu":({
		"congxianzhen/shangshanlu","congxianzhen/dashanshu",
		"congxianzhen/dashuyin","congxianzhen/shanshulin",
		"congxianzhen/shanshulinxiaolu","congxianzhen/suishizilu",
	}),
	"minglingzhihai/minglingqianhai":({
		"minglingzhihai/minglingqianhai","minglingzhihai/qianhaigou",
		"minglingzhihai/shenhaigou","minglingzhihai/wucaijiaoshi",
		"minglingzhihai/youanhaidi","minglingzhihai/minglinganyong",
	}),
	"congxianzhen/xiaoshouxueyiceng":({
		"congxianzhen/xiaoshouxueyiceng","congxianzhen/xiaoshouxueerceng",
		"congxianzhen/didihu","congxianzhen/shifu",
		"congxianzhen/wuyaoyingrukou","congxianzhen/yanbi",
	}),
	"shanyaohaiwan/miwusenlin":({
		"shanyaohaiwan/miwusenlin","shanyaohaiwan/miwuxiaolu",
		"shanyaohaiwan/miwupubu","shanyaohaiwan/miwuduanya",
		"shanyaohaiwan/diwashuikeng","shanyaohaiwan/jujiaoshi",
	}),
	"huanyecun/huanyecun":({
		"huanyecun/huanyecun","huanyecun/baishizilu",
		"huanyecun/baiyuchanglang","huanyecun/baizhousenlin",
		"huanyecun/chuizhoupubu","huanyecun/huanyeduanqiao",
	}),
	"kunlunshan/piaohuaxi":({
		"kunlunshan/heiheyuan","kunlunshan/huaxuepingyuan",
		"kunlunshan/kunlunshanjiao","kunlunshan/mangyuan",
		"kunlunshan/qiancaohai","kunlunshan/piaohuaxi",
	}),
	"kulougang/kuguchalu":({
		"kulougang/kuguchalu","kulougang/baigudui",
		"kulougang/feiqimaolu","kulougang/guhuncaowu",
		"kulougang/heishuihe","kulougang/huianmiwu",
	}),
	"liehuoying/liehuonan":({
		"liehuoying/liehuonan","liehuoying/huolongqiao",
		"liehuoying/liehuobeishao","liehuoying/liehuodongshao",
		"liehuoying/liehuohuijin","liehuoying/liehuoyan",
	}),
	"kunlunshan/pubudongxuesanceng":({
		"kunlunshan/pubudongxuesanceng",
		"kunlunshan/pubudongxuesiceng",
		"kunlunshan/heiseyanxuesiceng",
	}),
	"mihuandao/nongwusenlin":({
		"mihuandao/nongwusenlin","mihuandao/fangcaoxiaolu",
		"mihuandao/huancaihu","mihuandao/lvyinshanqiu",
		"mihuandao/mihuancun","mihuandao/mihuanduanya",
	}),
	"kunlunshan/xiuxian":({
		"kunlunshan/xiuxian","kunlunshan/canyunjing",
		"kunlunshan/liuyunjing","kunlunshan/xiushu",
	}),
	"jinaodao/qianshakeng":({
		"jinaodao/qianshakeng","jinaodao/feituidu",
		"jinaodao/huangshagang","jinaodao/huangtupo",
		"jinaodao/kuzhulin",
	}),
	"kunlunshan/lianshen":({
		"kunlunshan/lianshen","kunlunshan/lianjin",
		"kunlunshan/lianjing","kunlunshan/lianqi",
	}),
	"jinaodao/duanmulin":({
		"jinaodao/duanmulin","jinaodao/feishagu",
		"jinaodao/heihuilindi","jinaodao/heiyankou",
		"jinaodao/jiaotupingyuan","jinaodao/liushakeng",
	}),
	"shierxianjing/taoyuantongjiuceng":({
		"shierxianjing/taoyuantongjiuceng",
		"shierxianjing/taoyuantongshiceng",
		"shierxianjing/taoyuantongshiyiceng",
		"shierxianjing/taoyuantongshierceng",
	}),
	"wugongdong/xieduhe":({
		"wugongdong/xieduhe","wugongdong/chongpidui",
		"wugongdong/duxiepubu","wugongdong/huachongdong",
		"wugongdong/tuipidixue",
	}),
	"shierxianjing/taoyuantongshijiuceng":({
		"shierxianjing/taoyuantongshijiuceng",
		"shierxianjing/taoyuantongershiceng",
		"shierxianjing/lingxiadongyiceng",
		"shierxianjing/luojiadongyiceng",
		"shierxianjing/magudongyiceng",
		"shierxianjing/erxianfeng",
	}),
	"wugongdong/rongchongfang":({
		"wugongdong/rongchongfang","wugongdong/baizuguodao",
		"wugongdong/chongshidijiao","wugongdong/darongdong",
		"wugongdong/dongcedongxue","wugongdong/duxiehukou",
	}),
	"shierxianjing/magudongshisanceng":({
		"shierxianjing/magudongshisanceng",
		"shierxianjing/magudongshisiceng",
		"shierxianjing/magudongshiwuceng",
		"shierxianjing/lingxiadongshisanceng",
	}),
	"wugongdong/wugongshenyuan":({
		"wugongdong/wugongshenyuan","wugongdong/duheyuan",
		"wugongdong/fuhuashi",
	}),
	"plshuige/qingyuntai":({
		"plshuige/qingyuntai","plshuige/yunwuxukong4",
		"plshuige/yunwuxukong5","plshuige/yunwuxukong6",
	}),
	"plshuige/liexiandao":({
		"plshuige/liexiandao","plshuige/yunzhongta4",
		"plshuige/yunzhongta5","plshuige/yunzhongta6",
	}),
	"liangjinghu/yinhuxuanqiao":({
		"liangjinghu/yinhuxuanqiao","liangjinghu/chaoyanglu",
		"liangjinghu/hanshuichi","liangjinghu/huayushuixie",
		"liangjinghu/jinghuaan","liangjinghu/jinghubei",
	}),
	"plshuige/mianyunti":({
		"plshuige/mianyunti","plshuige/luoyunpo",
		"plshuige/yunwuxukong13","plshuige/yunwuxukong14",
		"plshuige/yunwuxukong15","plshuige/yunwuxukong16",
	}),
	"plshuige/yunpulu":({
		"plshuige/yunpulu","plshuige/yinyulu",
		"plshuige/yunzhongta13","plshuige/yunzhongta14",
		"plshuige/yunzhongta15","plshuige/yunzhongta16",
	}),
	"liangjinghu/huayaotingyuan15":({
		"liangjinghu/huayaotingyuan15","liangjinghu/huayaotingyuan16",
		"liangjinghu/huayaotingyuan17","liangjinghu/hehuamigong15",
		"liangjinghu/hehuamigong16","liangjinghu/hehuamigong17",
	}),
	"xiqiwaicheng/nanchengqiangjiao":({
		"xiqiwaicheng/nanchengqiangjiao","xiqiwaicheng/qixinglou",
		"xiqiwaicheng/shunqiangdao","xiqiwaicheng/xiandiken",
		"xiqiwaicheng/xiqinanchenglou",
	}),
	"chaogewaicheng/chaogedongnanlou":({
		"chaogewaicheng/chaogedongnanlou","chaogewaicheng/chaogexinanlou",
		"chaogewaicheng/chenghedao","chaogewaicheng/chengheshuikou",
		"chaogewaicheng/donghuchenghe","chaogewaicheng/dongnanchengqiang",
	}),
	"muye/xicezhanhao":({
		"muye/xicezhanhao","muye/dongcezhanhao",
		"muye/jiaotulu","muye/zhoubingshaoka",
	}),
	"xiqiwaicheng/huanhuashuitai":({
		"xiqiwaicheng/huanhuashuitai","xiqiwaicheng/huixinghuayuan",
		"xiqiwaicheng/xiqilinyindao","xiqiwaicheng/yingtiantai",
		"xiqiwaicheng/zheyanglu",
	}),
	"chaogewaicheng/eluanshihetan":({
		"chaogewaicheng/eluanshihetan","chaogewaicheng/hebaomu",
		"chaogewaicheng/hegu","chaogewaicheng/huiyingu",
		"chaogewaicheng/tuanliuhehan","chaogewaicheng/yanxilu",
	}),
	"muye/guzhandao":({
		"muye/guzhandao","muye/bubingying","muye/chengtubiandao",
		"muye/chongyandao","muye/guoshandao","muye/huanghean",
	}),
	"muye/poyaozhen9":({
		"muye/poyaozhen9","muye/poyaozhen10",
		"muye/poyaozhen11","muye/poyaozhen12",
	}),
	"muye/fuluying9":({
		"muye/fuluying9","muye/fuluying10",
		"muye/fuluying11","muye/fuluying12",
	}),
	"muye/hexiyandong10":({
		"muye/hexiyandong10","muye/hexiyandong11",
		"muye/hexiyandong12","muye/hexiyandong13",
	}),
	"waihai/lingyicheng":({
		"waihai/lingyicheng","waihai/lingyixiaolu",
		"waihai/lvzaoqiantan","waihai/lvzaoshentan",
		"waihai/shanhuhouhai","waihai/shanhuqianhai",
	}),
	"waihai/qianhaiguanmucong":({
		"waihai/qianhaiguanmucong","waihai/lingyidongchukou",
		"waihai/qianhaigouzhongceng",
	}),
	"yandigu/xiaoshilu":({
		"yandigu/xiaoshilu","yandigu/douranting",
		"yandigu/fangzongwanlu","yandigu/fangzongxiaojing",
		"yandigu/konglinghe","yandigu/konglinghegu",
	}),
	"fuxishan/fuxidongrukou":({
		"fuxishan/fuxidongrukou","fuxishan/fuxidongyiceng",
		"fuxishan/fuxidongerceng","fuxishan/fuxidongsanceng",
		"fuxishan/fuxidongsiceng","fuxishan/fuxihe",
	}),
	"huangyuan/yingxielu":({
		"huangyuan/yingxielu","huangyuan/jigutulu",
		"huangyuan/jinsegulu","huangyuan/mingqiutonglu",
	}),
	"liuguangpingyuan/liuguangchalu":({
		"liuguangpingyuan/liuguangchalu","liuguangpingyuan/baixuejing",
		"yandigu/bieguchanglu","fuxishan/fuxihoushan",
		"bishuitan/bishuichalu",
	}),
	"plxianjing/dangyunshijie":({
		"plxianjing/dangyunshijie","plxianjing/dangyunshiqiao",
		"plxianjing/biboyang","plxianjing/binghuanbudao",
		"plxianjing/binghuanchanglu","plxianjing/binghuanyunwu",
	}),
	"plxianjing/binghuanyuntai":({
		"plxianjing/binghuanyuntai","plxianjing/binghuanxiaoxi",
		"plxianjing/ningxuehu","plxianjing/ningxuepubu",
		"plxianjing/ningxuewanlu","plxianjing/qinglianhuachi",
	}),
	"penglaihuanjing/yunyepingyuan":({
		"penglaihuanjing/yunyepingyuan","penglaihuanjing/duanyeya",
		"penglaihuanjing/sifangqiao","penglaihuanjing/yeyulin",
		"penglaihuanjing/yulinglu","penglaihuanjing/yunshuipubu",
	}),
	"penglaihuanjing/qiushuangshilu":({
		"penglaihuanjing/qiushuangshilu","penglaihuanjing/hongyeyuan",
		"penglaihuanjing/jinyeyuan","penglaihuanjing/liushuangpubu",
		"penglaihuanjing/luoshuanghu","penglaihuanjing/luoshuangya",
	}),
	"penglaihuanjing/liehuochitang":({
		"penglaihuanjing/liehuochitang","penglaihuanjing/bamianqiao",
		"penglaihuanjing/lierigaotai","penglaihuanjing/lieyanchanglu",
		"penglaihuanjing/lieyanhu","penglaihuanjing/lieyanpingyuan",
	}),
	"klshuanjingwaicheng/heiheyuan":({
		"klshuanjingwaicheng/heiheyuan","klshuanjingwaicheng/chishuiyuan",
		"klshuanjingwaicheng/didihu","klshuanjingwaicheng/heiseyanxue",
		"klshuanjingwaicheng/shifu",
	}),
	"klshuanjingwaicheng/heishandong":({
		"klshuanjingwaicheng/heishandong","klshuanjingwaicheng/dashanshu",
		"klshuanjingwaicheng/dashuyin","klshuanjingwaicheng/heichao",
		"klshuanjingwaicheng/shendidong",
	}),
	"plxianjing/chilingxiaolu":({
		"plxianjing/chilingxiaolu","plxianjing/chilingguanghuan",
		"plxianjing/chilingxijing","plxianjing/chilingxiliu",
		"plxianjing/chilingyunrao","plxianjing/chilingyuntai",
	}),
	"plxianjing/chiyuxiaolu":({
		"plxianjing/chiyuxiaolu","plxianjing/chiyuguanghuan",
		"plxianjing/chiyuxijing","plxianjing/chiyuxiliu",
		"plxianjing/chiyuyunrao","plxianjing/chiyuyuntai",
	}),
	"penglaihuanjing/qiushuangxiaojing":({
		"penglaihuanjing/qiushuangxiaojing","penglaihuanjing/hongyeyuan",
		"penglaihuanjing/jinyeyuan","penglaihuanjing/liushuangpubu",
		"penglaihuanjing/luoshuanghu","penglaihuanjing/luoshuangya",
	}),
	"jiuxiaojiejing/jiuxiaotianmen":({
		"jiuxiaojiejing/jiuxiaotianmen","jiuxiaojiejing/xinghedu",
		"jiuxiaojiejing/wuxiangyuntai",
	}),
]);

private mapping(string:mixed) attach_training_route_pool(
	mapping(string:mixed) route)
{
	string path=(string)route["path"];
	array(string) paths=training_route_pools[path];
	if(!paths || !sizeof(paths))
		paths=({path});
	route["paths"]=copy_value(paths);
	route["pool_key"]=path;
	return route;
}

// 练级路线是启动后只读的配置快照。查询时返回副本，调用者不能改写
// 守护进程内缓存。
private mapping(string:mapping(int:mapping(string:mixed)))
	training_route_cache = ([]);

private void build_training_route_cache()
{
	mapping(string:mapping(int:mapping(string:mixed))) next_cache = ([
		"human":([]),
		"monst":([]),
		"third":([]),
	]);
	foreach(({"human","monst","third"}),string race){
		for(int level=1;level<70;level++){
			foreach(smart_training_routes,mapping(string:mixed) one){
				if(level>(int)one["max"])
					continue;
				mapping(string:mixed) route = copy_value(one);
				string path = (string)one[race];
				if(path=="")
					path = (string)one["third"];
				if(path=="")
					path = (string)one["human"];
				route["path"] = path;
				if((int)one[race+"_level"]>0)
					route["level"]=(int)one[race+"_level"];
				route = attach_training_route_pool(route);
				// 50级后多数路线随玩家等级提升，但不能把地图真实的
				// 最低怪物等级向下覆盖。典型边界是59级进入60级云野：
				// 推荐等级必须保持60，否则安全窗口会把整张图过滤掉。
				if(level>=50 && level>(int)route["level"])
					route["level"] = level;
				next_cache[race][level] = route;
				break;
			}
		}
	}
	training_route_cache = next_cache;
}

protected void create()
{
	server_autofight_view_generation = sprintf("%d-%d",
		time(),random(1000000000));
	build_training_route_cache();
}

mapping query_training_route_cache_status()
{
	return ([
		"mode":"immutable_snapshot",
		"pool_mode":"least_loaded_stable",
		"pool_count":sizeof(training_route_pools),
		"human":sizeof(training_route_cache["human"] || ([])),
		"monst":sizeof(training_route_cache["monst"] || ([])),
		"third":sizeof(training_route_cache["third"] || ([])),
	]);
}

mapping query_autofight_performance_status()
{
	return ([
		"scan_count":autofight_scan_count,
		"scan_object_budget":AUTOFIGHT_SCAN_MAX_OBJECTS,
		"deferred_objects":autofight_scan_deferred_objects,
		"server_scheduler":"single_global_callout",
		"server_tick_seconds":AUTOFIGHT_SERVER_TICK_SECONDS,
		"server_scan_budget":AUTOFIGHT_SERVER_SCAN_BUDGET,
		"server_normal_dispatch_budget":
			AUTOFIGHT_SERVER_NORMAL_DISPATCH_BUDGET,
		"server_pressure_dispatch_budget":
			AUTOFIGHT_SERVER_PRESSURE_DISPATCH_BUDGET,
		"server_severe_dispatch_budget":
			AUTOFIGHT_SERVER_SEVERE_DISPATCH_BUDGET,
		"server_last_dispatch_budget":server_autofight_last_dispatch_budget,
		"server_pressure_pending":AUTOFIGHT_SERVER_PRESSURE_PENDING,
		"server_severe_pending":AUTOFIGHT_SERVER_SEVERE_PENDING,
		"server_last_world_pending":server_autofight_last_world_pending,
		"server_last_pressure_level":server_autofight_last_pressure_level,
		"server_pressure_evaluations":
			server_autofight_pressure_evaluations,
		"server_severe_pressure_evaluations":
			server_autofight_severe_pressure_evaluations,
		"server_throttled_batches":server_autofight_throttled_batches,
		"server_active_users":sizeof(server_autofight_epochs),
		"server_inflight":sizeof(server_autofight_inflight),
		"server_inflight_timeout_seconds":AUTOFIGHT_SERVER_INFLIGHT_TIMEOUT,
		"server_inflight_timeouts":server_autofight_inflight_timeouts,
		"server_inflight_backlog_protected":
			server_autofight_inflight_backlog_protected,
		"server_cycle_remaining":server_autofight_cycle_remaining,
		"server_ticks":server_autofight_ticks,
		"server_enqueued":server_autofight_enqueued,
		"server_inflight_skipped":server_autofight_coalesced,
		"server_queue_rejected":server_autofight_rejected,
		"server_oversized_views":server_autofight_oversized_views,
		"server_cached_views":sizeof(server_autofight_views),
		"server_cleanup_scheduled":server_autofight_cleanup_scheduled,
		"training_pool_count":sizeof(training_route_pools),
		"training_reroutes":autofight_training_reroutes,
		"pressure_refills":autofight_pressure_refills,
		"overflow_rooms":autofight_overflow_room_count,
		"overflow_created":autofight_overflow_created,
		"overflow_destroyed":autofight_overflow_destroyed,
		"overflow_limit_fallbacks":autofight_overflow_limit_fallbacks,
		"overflow_global_limit":AUTOFIGHT_OVERFLOW_GLOBAL_LIMIT,
	]);
}

private array(object) query_bounded_scan_slice(object me,
	array(object) all,string cursor_key)
{
	array(object) result = ({});
	object env;
	string room_key;
	string room_identity;
	int total;
	int start;
	int count;
	if(!me || !all)
		return result;
	env = environment(me);
	room_key = cursor_key+"_room";
	room_identity = env ? file_name(env) : "";
	if((string)me[room_key]!=room_identity){
		me[cursor_key] = 0;
		me[room_key] = room_identity;
	}
	total = sizeof(all);
	start = (int)me[cursor_key];
	if(start<0 || start>=total)
		start = 0;
	count = total-start;
	if(count>AUTOFIGHT_SCAN_MAX_OBJECTS)
		count = AUTOFIGHT_SCAN_MAX_OBJECTS;
	if(count>0)
		result = all[start..start+count-1];
	if(start+count>=total)
		me[cursor_key] = 0;
	else{
		me[cursor_key] = start+count;
		autofight_scan_deferred_objects += total-start-count;
	}
	return result;
}

private void reset_scan_state(object me)
{
	if(!me)
		return;
	foreach(({"/tmp/autofight_scan_cursor",
		"/tmp/autofight_gather_scan_cursor",
		"/tmp/autofight_loot_scan_cursor"}),string key){
		me[key] = 0;
		me[key+"_room"] = "";
	}
	me["/tmp/autofight_scan_visible_total"] = 0;
}

void initialize_player(object me)
{
	int config_version;
	int daily_limit;
	if(!me)
		return;
	if(!(int)me["/plus/autofight_initialized"]){
		daily_limit = query_daily_seconds_for(me);
		me["/plus/autofight_initialized"] = 1;
		me["/plus/autofight_daily_limit"] = daily_limit;
		me["/plus/autofight_time_left"] = daily_limit;
		if(me->query_level()<=NEWBIED->query_newbie_supply_max_level()){
			me["/plus/autofight_hp_percent"] = 70;
			me["/plus/autofight_mana_percent"] = 50;
		}
		else{
			me["/plus/autofight_hp_percent"] = 50;
			me["/plus/autofight_mana_percent"] = 30;
		}
		me["/plus/autofight_loot"] = 1;
		me["/plus/autofight_roam"] = 0;
		me["/plus/autofight_smart_route"] = 1;
		me["/plus/autofight_auto_rest"] = 1;
		me["/plus/autofight_food"] = "auto";
		me["/plus/autofight_water"] = "auto";
		me["/plus/autofight_auto_sell_mode"] = "off";
		me["/plus/autofight_sell_weapon"] = 1;
		me["/plus/autofight_sell_armor"] = 1;
		me["/plus/autofight_sell_accessory"] = 1;
		me["/plus/autofight_sell_level_gap"] = 5;
		me["/plus/autofight_gather_mode"] = "off";
		me["/plus/autofight_material_keep"] = -1;
		me["/plus/autofight_destroy_non_equipment"] = 0;
		me["/plus/autofight_store_non_equipment"] = 0;
		me["/plus/autofight_cleanup_herb"] = 1;
		me["/plus/autofight_cleanup_mine"] = 1;
		me["/plus/autofight_cleanup_misc"] = 0;
		me["/plus/autofight_cleanup_keep"] = 100;
		me["/plus/autofight_cleanup_trigger"] = 70;
		me["/plus/autofight_cleanup_protect_names"] = "";
		me["/plus/autofight_cleanup_force_names"] = "";
		me["/plus/autofight_skill_mode"] = "smart";
		me["/plus/autofight_buff"] = 0;
	}
	else
		sync_daily_limit(me);
	config_version =
		(int)me["/plus/autofight_config_version"];
	if(config_version < 2){
		me["/plus/autofight_smart_route"] = 1;
		me["/plus/autofight_auto_rest"] = 1;
	}
	if(config_version < 3){
		me["/plus/autofight_auto_sell_mode"] = "off";
		me["/plus/autofight_sell_weapon"] = 1;
		me["/plus/autofight_sell_armor"] = 1;
		me["/plus/autofight_sell_accessory"] = 1;
		me["/plus/autofight_sell_level_gap"] = 5;
	}
	if(config_version < 4){
		me["/plus/autofight_gather_mode"] = "off";
		me["/plus/autofight_material_keep"] = -1;
	}
	if(config_version < 5)
		me["/plus/autofight_destroy_non_equipment"] = 0;
	if(config_version < 6){
		me["/plus/autofight_store_non_equipment"] = 0;
		me["/plus/autofight_cleanup_herb"] = 1;
		me["/plus/autofight_cleanup_mine"] = 1;
		me["/plus/autofight_cleanup_misc"] = 0;
		me["/plus/autofight_cleanup_keep"] = 100;
		me["/plus/autofight_cleanup_trigger"] = 70;
		me["/plus/autofight_cleanup_protect_names"] = "";
		me["/plus/autofight_cleanup_force_names"] = "";
	}
	if(config_version < 7)
		me["/plus/autofight_skill_mode"] = "smart";
	if(config_version < 8)
		me["/plus/autofight_buff"] = 0;
	if(config_version < 9){
		// 旧存档只有一个 skills_enable；原样迁入第一优先级，另外两格
		// 留空。绝不凭名称猜测或改动玩家已经选择的技能。
		string legacy_skill=(string)(me->skills_enable || "");
		me["/plus/autofight_skill_queue"] =
			({legacy_skill,"",""});
	}
	if(config_version < AUTOFIGHT_CONFIG_VERSION)
		me["/plus/autofight_config_version"] =
			AUTOFIGHT_CONFIG_VERSION;
	// daemon 热重载后运行态映射为空；状态查询会在不改变人物数据的
	// 前提下恢复已开启玩家的服务端调度。
	if(functionp(me->query_autofight) &&
	   me->query_autofight()=="enable")
		ensure_server_autofight_tick(me);
}

int query_daily_seconds()
{
	return AUTOFIGHT_DAILY_SECONDS;
}

int query_vip_level(object me)
{
	int vip_level;
	if(!me)
		return 0;
	// 会员标志和到期时间必须同时有效，防止过期存档继续获得挂机额度。
	vip_level = VIPD->query_active_vip_level(me);
	if(vip_level < 0)
		vip_level = 0;
	if(vip_level > AUTOFIGHT_MAX_VIP_LEVEL)
		vip_level = AUTOFIGHT_MAX_VIP_LEVEL;
	return vip_level;
}

string query_vip_label(int vip_level)
{
	string vip_name;
	if(vip_level <= 0)
		return "普通玩家";
	if(vip_level > AUTOFIGHT_MAX_VIP_LEVEL)
		vip_level = AUTOFIGHT_MAX_VIP_LEVEL;
	vip_name = VIPD->get_vip_name(vip_level);
	if(!vip_name || vip_name == "")
		return "VIP"+vip_level;
	return "VIP"+vip_level+"（"+vip_name+"）";
}

int query_daily_seconds_for(object me)
{
	return AUTOFIGHT_DAILY_SECONDS+
		query_vip_level(me)*AUTOFIGHT_VIP_BONUS_SECONDS;
}

int can_upgrade_daily_time(object me)
{
	return query_vip_level(me) < AUTOFIGHT_MAX_VIP_LEVEL;
}

string query_quota_exhausted_message(object me)
{
	int vip_level;
	int daily_hours;
	vip_level = query_vip_level(me);
	daily_hours = query_daily_seconds_for(me)/3600;
	if(vip_level < AUTOFIGHT_MAX_VIP_LEVEL)
		return sprintf("今天的%d小时自动挂机时间已经用完；升级至%s可将每日额度提高到%d小时",
			daily_hours,query_vip_label(vip_level+1),daily_hours+2);
	return sprintf("今天的%d小时自动挂机时间已经用完；你已是%s，当前为最高额度，请明日登录后再使用",
		daily_hours,query_vip_label(vip_level));
}

int is_quota_exhausted_reason(object me,string reason)
{
	if(!me || !reason || reason == "")
		return 0;
	return query_time_left(me) <= 0 &&
		reason == query_quota_exhausted_message(me);
}

void sync_daily_limit(object me)
{
	int daily_limit;
	int previous_limit;
	int time_left;
	if(!me)
		return;
	daily_limit = query_daily_seconds_for(me);
	previous_limit = (int)me["/plus/autofight_daily_limit"];
	if(previous_limit <= 0)
		previous_limit = AUTOFIGHT_DAILY_SECONDS;
	time_left = (int)me["/plus/autofight_time_left"];
	if(previous_limit != daily_limit)
		time_left += daily_limit-previous_limit;
	if(time_left < 0)
		time_left = 0;
	if(time_left > daily_limit)
		time_left = daily_limit;
	me["/plus/autofight_daily_limit"] = daily_limit;
	me["/plus/autofight_time_left"] = time_left;
}

void reset_daily_time(object me)
{
	int daily_limit;
	if(!me)
		return;
	// A first-day reset must populate the complete safe defaults before it
	// marks the helper initialized; otherwise new characters keep zero-valued
	// recovery and cleanup settings for the entire day.
	initialize_player(me);
	daily_limit = query_daily_seconds_for(me);
	me["/plus/autofight_initialized"] = 1;
	me["/plus/autofight_daily_limit"] = daily_limit;
	me["/plus/autofight_time_left"] = daily_limit;
	me["/tmp/autofight_last_charge"] = 0;
}

int query_time_left(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_time_left"];
}

// 装备耐久预警：任何一件已装备物品耐久 < 10% 时每 60 秒提醒一次，
// 不强制停止（玩家可能就是想消耗完再换）。state 在 /tmp/autofight_dura_warn_time。
string maybe_durability_warning(object me)
{
	int now;
	int last_warn;
	mixed equip_mixed;
	mapping equip;
	string low_name;
	int low_ratio;
	if(!me)
		return "";
	// 没装备查询接口直接跳过（防止对未实现接口的对象报错）
	if(!functionp(me->query_equip))
		return "";
	now = time();
	last_warn = (int)me["/tmp/autofight_dura_warn_time"];
	if(now-last_warn < 60)
		return "";
	// 用 catch 包裹，避免任何装备对象的异常影响挂机主循环
	equip_mixed = catch { equip = me->query_equip(); };
	if(equip_mixed || !mappingp(equip) || sizeof(equip)==0)
		return "";
	low_name = "";
	low_ratio = 100;
	foreach(indices(equip),string slot){
		object ob = equip[slot];
		int cur;
		int max;
		int ratio;
		string name_cn;
		if(!objectp(ob))
			continue;
		// 没耐久接口的物品（任务物品/戒指项链等）跳过
		if(!functionp(ob->query_item_dura))
			continue;
		cur = (int)ob->item_cur_dura;
		max = (int)ob->query_item_dura();
		if(max <= 0)
			continue;
		ratio = cur*100/max;
		if(ratio >= 10 || ratio >= low_ratio)
			continue;
		low_ratio = ratio;
		name_cn = "";
		if(functionp(ob->query_name_cn))
			name_cn = (string)ob->query_name_cn();
		if(name_cn == "" && functionp(ob->query_name))
			name_cn = (string)ob->query_name();
		low_name = name_cn;
	}
	if(low_name == "")
		return "";
	me["/tmp/autofight_dura_warn_time"] = now;
	return "⚠️ 装备【"+low_name+"】耐久仅剩"+(string)low_ratio+"%，即将损坏";
}

string maybe_quota_warning(object me)
{
	int left;
	int warned;
	if(!me)
		return "";
	left = query_time_left(me);
	warned = (int)me["/tmp/autofight_quota_warned"];
	if(left > 0 && left <= 60 && warned < 2){
		me["/tmp/autofight_quota_warned"] = 2;
		return "⚠️ 挂机时间将在 1 分钟内用完，请尽快处理手头事务";
	}
	if(left > 60 && left <= 300 && warned < 1){
		me["/tmp/autofight_quota_warned"] = 1;
		return "⚠️ 挂机时间将在 5 分钟内用完";
	}
	// 时间被补充（VIP 升级 / 次日刷新）→ 重置警告，下次到点能再提
	if(left > 300 && warned > 0)
		me["/tmp/autofight_quota_warned"] = 0;
	return "";
}

int query_hp_percent(object me)
{
	int percent;
	if(!me)
		return 50;
	initialize_player(me);
	percent = (int)me["/plus/autofight_hp_percent"];
	if(percent != 30 && percent != 50 && percent != 70)
		percent = 50;
	return percent;
}

int query_mana_percent(object me)
{
	int percent;
	if(!me)
		return 30;
	initialize_player(me);
	percent = (int)me["/plus/autofight_mana_percent"];
	if(percent != 0 && percent != 30 && percent != 50)
		percent = 30;
	return percent;
}

string query_auto_skill_mode(object me)
{
	string mode;
	if(!me)
		return "off";
	initialize_player(me);
	mode = (string)me["/plus/autofight_skill_mode"];
	if(mode != "smart" && mode != "manual" && mode != "off")
		mode = "smart";
	return mode;
}

string query_auto_skill_mode_cn(object me)
{
	string mode;
	mode = query_auto_skill_mode(me);
	if(mode == "smart")
		return "智能推荐";
	if(mode == "manual")
		return "手动指定";
	return "关闭";
}

// 技能守护进程采用惰性注册。重启后，老人物已学技能可能尚未被任何
// 商店或页面加载；自动挂机必须按受限文件名补载，不能依赖测试顺序。
object|zero query_auto_skill_object(string name)
{
	object|zero skill = 0;
	mixed err = 0;
	if(!name || name == "" || search(name,"/") != -1 ||
	   search(name,"..") != -1)
		return 0;
	skill = MUD_SKILLSD[name];
	if(!skill){
		err = catch {
			skill = (object)(ROOT+"/gamelib/single/skills/"+name);
		};
		if(err)
			skill = 0;
	}
	return skill;
}

private int query_auto_skill_owned(object me,string name)
{
	if(!me || !name || name=="")
		return 0;
	if(NEWMOON_SET_SKILLD->query_active_skill_level(me,name)>0)
		return 1;
	return me->skills && me->skills[name] &&
		(int)me->skills[name][0]>0;
}

private int query_auto_skill_usable_level(object me,string name)
{
	object|zero skill;
	mapping(int:int) limits;
	array(int) levels;
	int learned_level;
	int usable_level;
	if(!me || !name || name == "")
		return 0;
	skill = query_auto_skill_object(name);
	if(!skill || skill->s_type != "zhudong")
		return 0;
	usable_level=NEWMOON_SET_SKILLD->query_active_skill_level(me,name);
	if(usable_level>0)
		return usable_level;
	if(!me->skills || !me->skills[name])
		return 0;
	learned_level = (int)me->skills[name][0];
	if(learned_level <= 0)
		return 0;
	limits = skill->query_performs_level_limit_all ?
		skill->query_performs_level_limit_all() : 0;
	if(!limits || !sizeof(limits))
		return learned_level;
	if(sizeof(limits) == 1){
		if(me->query_level() < (int)limits[1])
			return 0;
		return learned_level;
	}
	levels = sort(indices(limits));
	usable_level = 0;
	for(int i = 0;i < sizeof(levels);i++){
		if(me->query_level() >= (int)limits[levels[i]])
			usable_level = levels[i];
	}
	if(usable_level > learned_level)
		usable_level = learned_level;
	return usable_level;
}

private int query_auto_attack_skill_priority(object skill)
{
	string skill_type;
	if(!skill || skill->s_type != "zhudong")
		return 0;
	skill_type = (string)skill->s_skill_type;
	if(skill_type == "phy" || skill_type == "huo_mofa_attack" ||
	   skill_type == "bing_mofa_attack" ||
	   skill_type == "feng_mofa_attack" ||
	   skill_type == "du_mofa_attack")
		return 3;
	if(skill_type == "dot")
		return 2;
	if(skill_type == "curse")
		return 1;
	return 0;
}

string query_recommended_auto_skill(object me)
{
	array(string) recommendations=query_recommended_auto_skills(me);
	return sizeof(recommendations) ? recommendations[0] : "";
}

array(string) query_recommended_auto_skills(object me)
{
	mapping learned;
	array(string) names;
	array(string) result=({});
	object|zero skill;
	string best_name;
	string name;
	int usable_level;
	int priority;
	int power;
	int magic_low;
	int magic_high;
	int cast;
	int score;
	int best_score;
	if(!me)
		return result;
	learned = me->skills || ([]);
	names = sort(indices(learned));
	string set_skill=NEWMOON_SET_SKILLD->query_active_skill_name(me);
	if(set_skill!="" && search(names,set_skill)==-1)
		names+=({set_skill});
	if(!sizeof(names))
		return result;
	for(int pick=0;pick<AUTOFIGHT_SKILL_QUEUE_SIZE;pick++){
		best_name = "";
		best_score = -1;
		for(int i = 0;i < sizeof(names);i++){
			name = names[i];
			if(search(result,name)!=-1)
				continue;
			skill = query_auto_skill_object(name);
			priority = query_auto_attack_skill_priority(skill);
			if(priority <= 0)
				continue;
			usable_level = query_auto_skill_usable_level(me,name);
			if(usable_level <= 0)
				continue;
			// 老技能和测试注入条目可能声明为主动攻击，却没有完整施放
			// 接口。智能扫描处必须失败关闭，不能让一次异常档案打断人物
			// 战斗心跳乃至整个Worker。
			if(!functionp(skill->query_performs_cast) ||
			   !functionp(skill->query_s_delayTime))
				continue;
			cast = skill->query_performs_cast(usable_level);
			if(cast > me->query_mofa_max())
				continue;
			power = functionp(skill->query_performs_attack) ?
				skill->query_performs_attack(usable_level) : 0;
			if(skill->s_skill_type == "huo_mofa_attack" ||
			   skill->s_skill_type == "bing_mofa_attack" ||
			   skill->s_skill_type == "feng_mofa_attack" ||
			   skill->s_skill_type == "du_mofa_attack"){
				if(!functionp(skill->query_performs_mofa_attack_low) ||
				   !functionp(skill->query_performs_mofa_attack_high))
					continue;
				magic_low = skill->query_performs_mofa_attack_low(usable_level);
				magic_high = skill->query_performs_mofa_attack_high(usable_level);
				power = (magic_low+magic_high)/2;
			}
			score = priority*100000000+usable_level*100000+power;
			if(score > best_score){
				best_score = score;
				best_name = name;
			}
		}
		if(best_name=="")
			break;
		result += ({best_name});
	}
	return result;
}

private void persist_auto_skill_queue(object me,array(string) queue)
{
	object|zero skill;
	int set_skill_level;
	if(!me)
		return;
	while(sizeof(queue)<AUTOFIGHT_SKILL_QUEUE_SIZE)
		queue += ({""});
	if(sizeof(queue)>AUTOFIGHT_SKILL_QUEUE_SIZE)
		queue = queue[..AUTOFIGHT_SKILL_QUEUE_SIZE-1];
	me["/plus/autofight_skill_queue"] = queue+({});
	// skills_enable 是历史存档/API字段，继续镜像第一优先级，避免旧JSP、
	// 旧书签和外部管理脚本突然失去兼容性。
	me->skills_enable = queue[0];
	skill = queue[0]!="" ? query_auto_skill_object(queue[0]) : 0;
	set_skill_level=queue[0]!="" ? NEWMOON_SET_SKILLD->
		query_active_skill_level(me,queue[0]) : 0;
	me->skills_enable_colddown = skill &&
		functionp(skill->query_s_delayTime) ?
		(set_skill_level>0 ? skill->query_s_delayTime(set_skill_level) :
			skill->query_s_delayTime())+1 : 0;
}

array(string) query_auto_skill_queue(object me)
{
	array(string) queue=({"","" ,""});
	multiset(string) seen=(<>);
	mixed stored;
	if(!me)
		return queue;
	initialize_player(me);
	stored=me["/plus/autofight_skill_queue"];
	if(arrayp(stored)){
		for(int i=0;i<AUTOFIGHT_SKILL_QUEUE_SIZE && i<sizeof(stored);i++){
			string name=stringp(stored[i]) ? (string)stored[i] : "";
			object|zero skill;
			if(name=="" || seen[name] ||
			   !query_auto_skill_owned(me,name))
				continue;
			skill=query_auto_skill_object(name);
			if(!skill || skill->s_type!="zhudong" ||
			   !functionp(skill->query_performs_cast) ||
			   !functionp(skill->query_s_delayTime))
				continue;
			queue[i]=name;
			seen[name]=1;
		}
	}
	// 战斗心跳会频繁读取队列。只有清理了无效/重复项，或旧兼容字段
	// 尚未同步时才回写，避免每拍重复改人物 mapping。
	if(!arrayp(stored) || !equal(queue,stored) ||
	   (string)(me->skills_enable || "")!=queue[0])
		persist_auto_skill_queue(me,queue);
	return queue+({});
}

int set_auto_skill_mode(object me,string mode)
{
	if(!me || (mode != "smart" && mode != "off"))
		return 0;
	me["/plus/autofight_skill_mode"] = mode;
	persist_auto_skill_queue(me,({"","",""}));
	me["/tmp/autofight_skill_refresh_at"] = 0;
	if(mode == "smart")
		ensure_auto_skill(me);
	return 1;
}

int set_selected_auto_skill(object me,string name,void|int slot)
{
	object|zero skill;
	array(string) queue;
	if(!me || !name || name == "" ||
	   !query_auto_skill_owned(me,name))
		return 0;
	if(!slot)
		slot=1;
	if(slot<1 || slot>AUTOFIGHT_SKILL_QUEUE_SIZE)
		return 0;
	skill = query_auto_skill_object(name);
	if(!skill || skill->s_type != "zhudong" ||
	   !functionp(skill->query_performs_cast) ||
	   !functionp(skill->query_s_delayTime))
		return 0;
	queue=query_auto_skill_queue(me);
	// 同一个技能只能占一个优先级。移位时先清旧位置再落新位置。
	for(int i=0;i<sizeof(queue);i++)
		if(queue[i]==name)
			queue[i]="";
	queue[slot-1]=name;
	me["/plus/autofight_skill_mode"] = "manual";
	persist_auto_skill_queue(me,queue);
	return 1;
}

int clear_auto_skill_slot(object me,int slot)
{
	array(string) queue;
	if(!me || slot<1 || slot>AUTOFIGHT_SKILL_QUEUE_SIZE)
		return 0;
	queue=query_auto_skill_queue(me);
	queue[slot-1]="";
	persist_auto_skill_queue(me,queue);
	if(queue*""=="")
		me["/plus/autofight_skill_mode"]="off";
	return 1;
}

int clear_selected_auto_skill(object me,string name)
{
	array(string) queue;
	int changed;
	if(!me || !name || name=="")
		return 0;
	queue=query_auto_skill_queue(me);
	for(int i=0;i<sizeof(queue);i++)
		if(queue[i]==name){
			queue[i]="";
			changed=1;
		}
	if(!changed)
		return 0;
	persist_auto_skill_queue(me,queue);
	if(queue*""=="")
		me["/plus/autofight_skill_mode"]="off";
	return 1;
}

string ensure_auto_skill(object me)
{
	array(string) queue;
	array(string) recommended;
	string mode;
	int refresh_at;
	int needs_refresh;
	if(!me)
		return "";
	mode = query_auto_skill_mode(me);
	if(mode == "off")
		return "";
	queue=query_auto_skill_queue(me);
	if(mode=="smart"){
		refresh_at=(int)me["/tmp/autofight_skill_refresh_at"];
		needs_refresh=refresh_at<=time() || queue*""=="";
		// 队列中的技能若刚被遗忘或失效，不等待缓存到期。
		if(!needs_refresh)
			foreach(queue,string configured)
				if(configured!="" && query_auto_skill_usable_level(
				   me,configured)<=0){
					needs_refresh=1;
					break;
				}
		if(needs_refresh){
			recommended=query_recommended_auto_skills(me);
			queue=({"","",""});
			for(int i=0;i<sizeof(recommended) &&
			   i<AUTOFIGHT_SKILL_QUEUE_SIZE;i++)
				queue[i]=recommended[i];
			persist_auto_skill_queue(me,queue);
			me["/tmp/autofight_skill_refresh_at"] =
				time()+AUTOFIGHT_SMART_SKILL_REFRESH_SECONDS;
		}
	}
	foreach(queue,string name)
		if(name!="")
			return name;
	return "";
}

string query_auto_skill_unready_reason(object me,string name)
{
	object|zero skill;
	int usable_level;
	int cast;
	if(!me || !name || name == "" ||
	   !query_auto_skill_owned(me,name))
		return "not_learned";
	skill = query_auto_skill_object(name);
	if(!skill)
		return "missing_skill";
	if(!functionp(skill->query_performs_cast) ||
	   !functionp(skill->query_s_delayTime))
		return "invalid_skill_api";
	usable_level = query_auto_skill_usable_level(me,name);
	if(usable_level <= 0)
		return "level_locked";
	if(me->timeCold != 0)
		return "global_cooldown";
	if(me->f_skills && (int)me->f_skills[name] > 1)
		return "skill_cooldown";
	cast = skill->query_performs_cast(usable_level);
	if(cast > me->get_cur_mofa())
		return "insufficient_mana";
	if(skill->s_skill_type == "phy"){
		mapping items=me->query_equip();
		if(!items || (!items["single_main_weapon"] &&
		   !items["double_main_weapon"]))
			return "missing_weapon";
	}
	return "";
}

private int query_context_skill_ready(object me,string name)
{
	return query_auto_skill_unready_reason(me,name) == "";
}

// 镇越智能挂机并非只挑最高伤害：失去仇恨时先震吼，护盾耗尽后
// 再保护同房间队伍，两个条件都不满足才回到常规高仇恨攻击。
string query_ready_zhenyue_context_skill(object me)
{
	array(string) names;
	if(!me || me->query_profeId() != "zhenyue" ||
	   !me->query_in_combat())
		return "";
	// 只由职业助手守护进程决定上下文优先级；守护进程同时校验
	// 有效档位、开关和PVE目标，PVP永远不会自动接管。
	names = PROFESSIONVIPD->query_zhenyue_context_candidates(me);
	foreach(names,string name)
		if(query_context_skill_ready(me,name))
			return name;
	return "";
}

// 天象智能挂机遵循真实星痕状态：低血量先补星壁，二至三层时按
// 策略引爆，否则轮换已学且已冷却的生成技能；职业助手不修改数值。
string query_ready_tianxiang_context_skill(object me)
{
	array(string) names;
	if(!me || me->query_profeId() != "tianxiang" ||
	   !me->query_in_combat())
		return "";
	names = PROFESSIONVIPD->query_tianxiang_context_candidates(me);
	foreach(names,string name)
		if(query_context_skill_ready(me,name))
			return name;
	return "";
}

// 灵医智能挂机仅在职业助手已授权的PVE战斗中插入治疗；目标、上限、
// 净化和药契仍由战斗引擎统一结算，助手不能改变任何技能数值。
string query_ready_lingyi_context_skill(object me)
{
	array(string) names;
	if(!me || me->query_profeId()!="lingyi" || !me->query_in_combat())
		return "";
	names = PROFESSIONVIPD->query_lingyi_context_candidates(me);
	foreach(names,string name)
		if(query_context_skill_ready(me,name))
			return name;
	return "";
}

string query_ready_auto_skill(object me)
{
	array(string) queue;
	string context_name;
	if(!me || !me->query_in_combat())
		return "";
	if(query_auto_skill_mode(me) == "smart"){
		if(me->query_profeId()=="tianxiang")
			context_name = query_ready_tianxiang_context_skill(me);
		else if(me->query_profeId()=="lingyi")
			context_name = query_ready_lingyi_context_skill(me);
		else
			context_name = query_ready_zhenyue_context_skill(me);
		if(context_name != "")
			return context_name;
	}
	ensure_auto_skill(me);
	queue=query_auto_skill_queue(me);
	foreach(queue,string name)
		if(name!="" && query_auto_skill_unready_reason(me,name)=="")
			return name;
	return "";
}

int query_loot_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_loot"] == 1;
}

int query_roam_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_roam"] == 1;
}

int query_smart_route_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_smart_route"] == 1;
}

int query_auto_rest_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_auto_rest"] == 1;
}

int query_auto_buff_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return (int)me["/plus/autofight_buff"] == 1;
}

// 选择某 kind 槽位下一次会被自动服用的丹药。返回 0 表示该槽位本轮不会触发：
// 可能因为槽位已有 buff、背包无候选丹药、等级超限、或 te_* 已达每日上限。
// 调用方负责缓存名称：吃下后 amount 归零，物品对象会被销毁。
private object|zero select_best_buff_danyao(object me, string kind)
{
	object|zero best;
	int best_value;
	int best_duration;
	mapping teyao_map;
	if(me->query_buff(kind, 0) != "none")
		return 0;
	if(has_prefix(kind,"te_")){
		teyao_map = me["/plus/daily/teyao_map"];
		if(mappingp(teyao_map) &&
		   (int)teyao_map[kind] >= (int)me->query_max_yao())
			return 0;
	}
	foreach(all_inventory(me), object item){
		int max_level;
		int value;
		int duration;
		if(!item || item->amount <= 0)
			continue;
		if(!functionp(item->query_danyao_kind))
			continue;
		if(item->query_danyao_kind() != kind)
			continue;
		max_level = (int)item->query_danyao_max_level();
		if(max_level > 0 && me->query_level() > max_level)
			continue;
		value = (int)item->query_effect_value();
		duration = (int)item->query_danyao_timedelay();
		if(!best || value > best_value ||
		   (value == best_value && duration > best_duration)){
			best = item;
			best_value = value;
			best_duration = duration;
		}
	}
	return best;
}

// 预览开关开启后、下一次脱战 tick 会自动服用的丹药。用于 autofight open 设置页展示，
// 让玩家在勾选开关时就能看到接下来哪些丹药会被消耗、对应什么属性。
array(mapping(string:mixed)) query_auto_buff_preview(object me)
{
	array(mapping(string:mixed)) preview = ({});
	mapping(string:string) kind_labels = ([
		"attri_base":"力量/敏捷/悟性",
		"attri_attack":"伤害",
		"attri_defend":"防御/生命",
		"attri_vice":"副属性",
		"attri_luck":"幸运",
		"attri_honer":"荣誉",
		"attri_exp":"经验",
		"te_base":"力量/敏捷/悟性（特）",
		"te_attack":"伤害（特）",
		"te_defend":"防御/生命（特）",
		"te_vice":"副属性（特）",
		"te_luck":"幸运（特）",
		"te_honer":"荣誉（特）",
		"te_exp":"经验（特）",
	]);
	if(!me)
		return preview;
	initialize_player(me);
	if((int)me["/plus/autofight_buff"] != 1)
		return preview;
	foreach(auto_buff_kinds, string kind){
		object|zero best = select_best_buff_danyao(me, kind);
		if(!best)
			continue;
		preview += ({
			([
				"kind":kind,
				"kind_cn":kind_labels[kind] || kind,
				"name_cn":best->query_name_cn(),
				"value":(int)best->query_effect_value(),
				"duration":(int)best->query_danyao_timedelay(),
			]),
		});
	}
	return preview;
}

mapping(string:mixed) perform_auto_buff(object me)
{
	mapping(string:mixed) result;
	result = (["eaten":({})]);
	if(!me)
		return result;
	initialize_player(me);
	if((int)me["/plus/autofight_buff"] != 1)
		return result;
	// 覆盖 attri_* 与 te_* 共十四类 buff 丹药；spec 因 sucide 会自杀，永远不自动吃。
	// 已有同类 buff 不覆盖；等级超限的追赶药跳过；te_* 每日次数到达上限后跳过。
	foreach(auto_buff_kinds, string kind){
		object|zero best;
		int count_index;
		string best_name;
		string best_name_cn;
		best = select_best_buff_danyao(me, kind);
		if(!best)
			continue;
		// 吃药前缓存名称：amount 减到 0 时物品会被销毁，之后再访问会报错。
		best_name = best->query_name();
		best_name_cn = best->query_name_cn();
		// present(name, me, n) 是 0-indexed：第一件同名物品传 0。
		count_index = query_object_count(best, me);
		// flag=1 强制覆盖现有 buff 的确认提示，跳过交互。
		me->command("viceskill_eat_danyao "+best_name+" "+
			count_index+" 1 0");
		if(me->query_buff(kind, 0) != "none")
			result["eaten"] += ({ best_name_cn });
	}
	return result;
}

int query_auto_destroy_non_equipment_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return query_vip_level(me) >= 1 &&
		(int)me["/plus/autofight_destroy_non_equipment"] == 1;
}

int query_auto_store_non_equipment_enabled(object me)
{
	if(!me)
		return 0;
	initialize_player(me);
	return query_vip_level(me) >= 1 &&
		(int)me["/plus/autofight_store_non_equipment"] == 1;
}

int query_auto_cleanup_trigger_percent(object me)
{
	int vip_level;
	int trigger;
	if(!me)
		return 100;
	initialize_player(me);
	vip_level = query_vip_level(me);
	if(vip_level >= 4){
		trigger = (int)me["/plus/autofight_cleanup_trigger"];
		if(trigger == 70 || trigger == 80 || trigger == 90)
			return trigger;
		return 70;
	}
	if(vip_level == 3)
		return 80;
	if(vip_level == 2)
		return 85;
	if(vip_level == 1)
		return 90;
	return 100;
}

int query_auto_cleanup_keep(object me)
{
	int keep;
	if(!me || query_vip_level(me) < 3)
		return 0;
	initialize_player(me);
	keep = (int)me["/plus/autofight_cleanup_keep"];
	if(keep != 0 && keep != 50 && keep != 100 && keep != 300)
		return 100;
	return keep;
}

int query_auto_cleanup_category_enabled(object me,string category)
{
	int vip_level;
	if(!me)
		return 0;
	initialize_player(me);
	vip_level = query_vip_level(me);
	if(vip_level < 1)
		return 0;
	if(vip_level == 1)
		return category == "herb" || category == "mine";
	if(category == "herb")
		return (int)me["/plus/autofight_cleanup_herb"] == 1;
	if(category == "mine")
		return (int)me["/plus/autofight_cleanup_mine"] == 1;
	if(category == "misc")
		return (int)me["/plus/autofight_cleanup_misc"] == 1;
	return 0;
}

private array(string) query_auto_cleanup_names(object me,string key)
{
	string raw;
	array(string) names;
	if(!me)
		return ({});
	raw = (string)me[key];
	if(!raw || raw == "")
		return ({});
	names = raw/","-({""});
	return names;
}

array(string) query_auto_cleanup_protect_names(object me)
{
	return query_auto_cleanup_names(me,
		"/plus/autofight_cleanup_protect_names");
}

array(string) query_auto_cleanup_force_names(object me)
{
	return query_auto_cleanup_names(me,
		"/plus/autofight_cleanup_force_names");
}

string query_auto_cleanup_name_mode(object me,string item_name)
{
	if(!me || !item_name)
		return "normal";
	if(search(query_auto_cleanup_protect_names(me),item_name) != -1)
		return "protect";
	if(search(query_auto_cleanup_force_names(me),item_name) != -1)
		return "force";
	return "normal";
}

int set_auto_cleanup_name_mode(object me,string item_name,string mode)
{
	array(string) protect_names;
	array(string) force_names;
	if(!me || !item_name || item_name == "" ||
	   search(item_name,",") != -1 || search(item_name," ") != -1)
		return 0;
	if(mode != "normal" && mode != "protect" && mode != "force")
		return 0;
	protect_names = query_auto_cleanup_protect_names(me)-({item_name});
	force_names = query_auto_cleanup_force_names(me)-({item_name});
	if(mode == "protect"){
		if(sizeof(protect_names) >= AUTOFIGHT_CLEANUP_NAME_LIMIT)
			return 0;
		protect_names += ({item_name});
	}
	else if(mode == "force"){
		if(sizeof(force_names) >= AUTOFIGHT_CLEANUP_NAME_LIMIT)
			return 0;
		force_names += ({item_name});
	}
	me["/plus/autofight_cleanup_protect_names"] = protect_names*",";
	me["/plus/autofight_cleanup_force_names"] = force_names*",";
	return 1;
}

string query_gather_mode(object me)
{
	string mode;
	array(string) valid_modes = ({"off","mine","herb","both"});
	if(!me)
		return "off";
	initialize_player(me);
	mode = (string)me["/plus/autofight_gather_mode"];
	if(search(valid_modes,mode) == -1)
		return "off";
	return mode;
}

string query_gather_mode_cn(string mode)
{
	if(mode == "mine")
		return "自动采矿";
	if(mode == "herb")
		return "自动采药";
	if(mode == "both")
		return "采药和采矿";
	return "关闭";
}

int query_material_keep(object me)
{
	int keep;
	if(!me)
		return -1;
	initialize_player(me);
	keep = (int)me["/plus/autofight_material_keep"];
	if(keep != -1 && keep != 0 && keep != 100 &&
	   keep != 300 && keep != 500)
		return -1;
	return keep;
}

object|zero query_gather_source(object me)
{
	object env;
	string mode;
	array(object) all;
	if(!me || me->in_combat)
		return 0;
	mode = query_gather_mode(me);
	if(mode == "off")
		return 0;
	env = environment(me);
	if(!env)
		return 0;
	all = query_bounded_scan_slice(me,all_inventory(env,me),
		"/tmp/autofight_gather_scan_cursor");
	foreach(all,object source){
		string source_type;
		string skill_name;
		mixed skill;
		int need_level;
		if(!source || !functionp(source->query_source_type))
			continue;
		source_type = source->query_source_type();
		if(source_type == "kuang"){
			if(mode != "mine" && mode != "both")
				continue;
			skill_name = "caikuang";
			need_level = KUANGD->query_need_level(source->query_name());
		}
		else if(source_type == "caoyao"){
			if(mode != "herb" && mode != "both")
				continue;
			skill_name = "caiyao";
			need_level = CAOYAOD->query_need_level(source->query_name());
		}
		else
			continue;
		skill = me->vice_skills[skill_name];
		if(!arrayp(skill) || !sizeof(skill))
			continue;
		if(need_level >= 0 && (int)skill[0] >= need_level)
			return source;
	}
	return 0;
}

string query_auto_sell_mode(object me)
{
	string mode;
	array(string) valid_modes = ({
		"off","normal","excellent","refined","huanhua",
	});
	if(!me)
		return "off";
	initialize_player(me);
	mode = (string)me["/plus/autofight_auto_sell_mode"];
	if(search(valid_modes,mode) == -1)
		return "off";
	return mode;
}

string query_auto_sell_mode_cn(string mode)
{
	if(mode == "normal")
		return "仅普通白装";
	if(mode == "excellent")
		return "普通及优良装备";
	if(mode == "refined")
		return "普通、优良及精制装备";
	if(mode == "huanhua")
		return "普通至幻化装备（高风险）";
	return "关闭";
}

int query_auto_sell_mode_requirement(string mode)
{
	if(mode == "normal")
		return 1;
	if(mode == "excellent")
		return 2;
	if(mode == "refined")
		return 3;
	if(mode == "huanhua")
		return 4;
	return 0;
}

int query_auto_sell_quality_limit(string mode)
{
	if(mode == "excellent")
		return 2;
	if(mode == "refined")
		return 4;
	if(mode == "huanhua")
		return 7;
	return 0;
}

int query_auto_sell_enabled(object me)
{
	string mode;
	int requirement;
	int vip_level;
	if(!me)
		return 0;
	mode = query_auto_sell_mode(me);
	requirement = query_auto_sell_mode_requirement(mode);
	vip_level = query_vip_level(me);
	return requirement > 0 && vip_level >= requirement &&
		vip_level >= query_auto_sell_gap_requirement(
			query_auto_sell_level_gap(me));
}

int query_auto_sell_trigger_percent(object me)
{
	int vip_level = query_vip_level(me);
	if(vip_level >= 4)
		return 70;
	if(vip_level == 3)
		return 80;
	if(vip_level == 2)
		return 90;
	return 100;
}

int query_auto_sell_batch_size(object me)
{
	if(!me)
		return 0;
	// 保留这个查询接口给旧页面使用，但自动出售不再人为切成1/2/4/8件。
	// 背包容量天然限定了单次工作量，符合规则的低级装备应一次清完，
	// 避免清了8件就返回战斗、下一次拾取时又被满包卡住。
	return sizeof(query_auto_sell_candidates(me));
}

int query_auto_sell_level_gap(object me)
{
	int gap;
	if(!me)
		return 5;
	initialize_player(me);
	gap = (int)me["/plus/autofight_sell_level_gap"];
	if(gap != 0 && gap != 3 && gap != 5)
		return 5;
	return gap;
}

int query_auto_sell_gap_requirement(int gap)
{
	if(gap == 0)
		return 3;
	if(gap == 3)
		return 2;
	return 1;
}

int query_backpack_percent(object me)
{
	int maximum;
	int count;
	if(!me)
		return 0;
	maximum = me->query_beibao_size();
	if(maximum <= 0)
		return 0;
	count = sizeof(all_inventory(me));
	return count*100/maximum;
}

private int is_auto_sell_equipment_type(object item)
{
	string item_type;
	if(!item)
		return 0;
	item_type = item->query_item_type();
	return item_type == "weapon" ||
		item_type == "single_weapon" ||
		item_type == "double_weapon" ||
		item_type == "armor" ||
		item_type == "jewelry" ||
		item_type == "decorate";
}

private int is_auto_sell_category_enabled(object me,object item)
{
	string item_type;
	if(!me || !item)
		return 0;
	item_type = item->query_item_type();
	if(item_type == "weapon" ||
	   item_type == "single_weapon" ||
	   item_type == "double_weapon")
		return (int)me["/plus/autofight_sell_weapon"] == 1;
	if(item_type == "armor")
		return (int)me["/plus/autofight_sell_armor"] == 1;
	if(item_type == "jewelry" || item_type == "decorate")
		return (int)me["/plus/autofight_sell_accessory"] == 1;
	return 0;
}

private int has_auto_sell_protected_gem(object item)
{
	array(string) colors = ({"blue","red","yellow"});
	if(!item || !functionp(item->query_baoshi))
		return 0;
	foreach(colors,string color){
		array(object) gems = item->query_baoshi(color);
		if(gems && sizeof(gems))
			return 1;
	}
	return 0;
}

private int has_auto_sell_protected_filename(object item)
{
	string path;
	if(!item)
		return 1;
	path = (file_name(item)/"#")[0];
	if(search(path,"/duanzao/") != -1 ||
	   search(path,"/suit_") != -1 ||
	   search(path,"Xa") != -1 ||
	   search(path,"Xl") != -1 ||
	   search(path,"Xh") != -1 ||
	   search(path,"Xf") != -1)
		return 1;
	return 0;
}

string query_auto_sell_reject_reason(object me,object item)
{
	string mode;
	string item_from;
	int level_gap;
	int item_level;
	if(!me || !item || environment(item) != me)
		return "not_in_backpack";
	if(!item->is("item") || !item->is("equip") ||
	   !is_auto_sell_equipment_type(item))
		return "not_equipment";
	if(!query_auto_sell_enabled(me))
		return "disabled";
	if(item->equiped)
		return "equipped";
	// 六系套装在首次穿戴前仍未绑定，且可拥有1～7条随机词缀。
	// 旧清包规则不能凭“未绑定/低稀有度”把它当成普通装备处理。
	// 套装只允许进入独立的套装管理流程，并经过重复件预览确认。
	if(functionp(item->query_newmoon_resonance_profession) &&
	   (string)item->query_newmoon_resonance_profession()!="" &&
	   functionp(item->query_newmoon_collection_id) &&
	   (string)item->query_newmoon_collection_id()!="")
		return "set_equipment";
	if(item->query_item_task() == 1)
		return "task_item";
	if(item->query_item_canTrade() != 1)
		return "not_tradeable";
	if(item->query_item_canDrop() != 1 ||
	   item->query_item_canStorage() != 1)
		return "restricted";
	if(item->query_item_only() == 1)
		return "unique";
	if(item->item_playerDesc && item->item_playerDesc != "")
		return "player_marked";
	item_from = item->query_item_from();
	if(item_from && item_from != "")
		return "special_source";
	if(has_auto_sell_protected_filename(item))
		return "forged_or_fused";
	if(functionp(item->query_convert_count) &&
	   item->query_convert_count() > 0)
		return "converted";
	if(has_auto_sell_protected_gem(item))
		return "socketed";
	// 空觉及以上始终是硬保护线，即使未来增加更高VIP档也不能越过。
	if(item->query_item_rareLevel() >= 8)
		return "rare";
	mode = query_auto_sell_mode(me);
	if(item->query_item_rareLevel() >
	   query_auto_sell_quality_limit(mode))
		return "quality";
	if(!is_auto_sell_category_enabled(me,item))
		return "category";
	item_level = item->query_item_canLevel();
	if(item_level < 0)
		return "no_level_requirement";
	level_gap = query_auto_sell_level_gap(me);
	// gap=0表示完全关闭等级差过滤，高于人物等级的装备也继续按品质、
	// 类别和永久保护规则处理；不能把0误解为“至少低0级”。
	if(level_gap>0 && item_level > me->query_level()-level_gap)
		return "recent_level";
	return "";
}

array(object) query_auto_sell_candidates(object me)
{
	array(object) candidates = ({});
	if(!me || !query_auto_sell_enabled(me))
		return candidates;
	foreach(all_inventory(me),object item){
		if(query_auto_sell_reject_reason(me,item) == "")
			candidates += ({item});
	}
	return candidates;
}

int should_auto_sell(object me)
{
	if(!me || !query_auto_sell_enabled(me))
		return 0;
	if(query_backpack_percent(me) <
	   query_auto_sell_trigger_percent(me))
		return 0;
	return sizeof(query_auto_sell_candidates(me)) > 0;
}

int query_auto_sell_value(object item)
{
	int money_num;
	if(!item || !is_auto_sell_equipment_type(item))
		return 0;
	money_num = (int)item->query_item_canLevel()*50/4;
	if(money_num <= 0)
		money_num = 1;
	return money_num;
}

mapping(string:mixed) perform_auto_sell(object me)
{
	mapping(string:mixed) result = ([
		"count":0,
		"money":0,
		"names":({}),
	]);
	array(object) candidates;
	if(!me || !query_auto_sell_enabled(me) || me->in_combat)
		return result;
	candidates = query_auto_sell_candidates(me);
	// 候选列表是单次只读快照；逐件出售前仍重新校验永久保护规则，
	// 即使处理中物品状态发生变化，也不会误卖受保护装备。
	for(int i = 0;i < sizeof(candidates);i++){
		object item = candidates[i];
		string item_name;
		string item_path;
		string now;
		int money_num;
		if(query_auto_sell_reject_reason(me,item) != "")
			continue;
		item_name = item->query_name_cn();
		item_path = (file_name(item)/"#")[0];
		money_num = query_auto_sell_value(item);
		me->add_money(money_num);
		result["count"] = (int)result["count"]+1;
		result["money"] = (int)result["money"]+money_num;
		result["names"] += ({item_name});
		now = ctime(time());
		ASYNC_IOD->append_log(ROOT+"/log/autofight_sell.log",
			now[0..sizeof(now)-2]+" "+me->query_name_cn()+"("+
			me->query_name()+") "+query_vip_label(query_vip_level(me))+
			" 自动出售 "+item_name+" "+item_path+" 得到"+
			money_num+"\n");
		item->remove();
	}
	return result;
}

private int is_auto_sell_material(object me,object item)
{
	string material_type;
	int keep;
	if(!me || !item || environment(item) != me)
		return 0;
	keep = query_material_keep(me);
	if(keep < 0 || !item->is("combine_item"))
		return 0;
	material_type = item->query_for_material();
	if(material_type != "duanzao" && material_type != "liandan")
		return 0;
	if(item->query_item_canTrade() != 1 || item->value <= 0)
		return 0;
	return item->amount > keep;
}

int consolidate_gathered_materials(object me)
{
	mapping(string:object) first_items = ([]);
	int removed = 0;
	if(!me)
		return 0;
	foreach(all_inventory(me),object item){
		string material_type;
		string key;
		object first;
		if(!item || !item->is("combine_item"))
			continue;
		material_type = item->query_for_material();
		if(material_type != "duanzao" && material_type != "liandan")
			continue;
		key = item->query_name()+"#"+item->query_toVip();
		first = first_items[key];
		item->max_count = 9999;
		if(!first){
			first_items[key] = item;
			continue;
		}
		int available = 9999-first->amount;
		if(available <= 0){
			first_items[key] = item;
			continue;
		}
		if(item->amount <= available){
			first->amount += item->amount;
			item->remove();
			removed++;
		}
		else{
			first->amount = 9999;
			item->amount -= available;
			first_items[key] = item;
		}
	}
	return removed;
}

object|zero query_auto_sell_material(object me)
{
	if(!me || query_material_keep(me) < 0)
		return 0;
	foreach(all_inventory(me),object item){
		if(is_auto_sell_material(me,item))
			return item;
	}
	return 0;
}

int should_auto_sell_material(object me)
{
	if(!me || me->in_combat)
		return 0;
	return query_auto_sell_material(me) ? 1 : 0;
}

mapping(string:mixed) perform_auto_sell_material(object me)
{
	mapping(string:mixed) result = ([
		"count":0,
		"money":0,
		"name":"",
	]);
	object|zero item;
	int keep;
	int sell_amount;
	int money_num;
	string item_name;
	string item_path;
	string now;
	if(!me || me->in_combat)
		return result;
	item = query_auto_sell_material(me);
	if(!item)
		return result;
	keep = query_material_keep(me);
	sell_amount = item->amount-keep;
	if(sell_amount <= 0)
		return result;
	item_name = item->query_name_cn();
	item_path = (file_name(item)/"#")[0];
	money_num = item->value*sell_amount;
	if(money_num <= 0)
		money_num = sell_amount;
	me->add_money(money_num);
	result["count"] = sell_amount;
	result["money"] = money_num;
	result["name"] = item_name;
	item->amount = keep;
	if(item->amount <= 0)
		item->remove();
	now = ctime(time());
	ASYNC_IOD->append_log(ROOT+"/log/autofight_material_sell.log",
		now[0..sizeof(now)-2]+" "+me->query_name_cn()+"("+
		me->query_name()+") 自动出售采集原料 "+item_name+" "+
		item_path+" 数量"+sell_amount+" 得到"+money_num+"\n");
	return result;
}

int query_non_equipment_destroy_item_amount(object item)
{
	if(!item)
		return 0;
	if(item->is("combine_item") && item->amount > 0)
		return item->amount;
	return 1;
}

string query_non_equipment_destroy_reject_reason(object me,object item)
{
	string item_type;
	string item_from;
	array(string) protected_types = ({
		"book","box","danyao","food","water","yushi",
	});
	if(!me || !item || environment(item) != me)
		return "not_in_backpack";
	if(!item->is("item"))
		return "not_item";
	item_type = item->query_item_type();
	if(item->is("equip") || is_auto_sell_equipment_type(item))
		return "equipment";
	if(search(protected_types,item_type) != -1)
		return "protected_type";
	if(item->query_item_task() == 1)
		return "task_item";
	if(item->query_item_canDrop() != 1)
		return "not_droppable";
	if(item->query_item_canTrade() != 1 ||
	   item->query_item_canStorage() != 1)
		return "restricted";
	if(item->query_toVip())
		return "vip_item";
	if(item->query_item_only() == 1)
		return "unique";
	if(item->item_playerDesc && item->item_playerDesc != "")
		return "player_marked";
	item_from = item->query_item_from();
	if(item_from && item_from != "")
		return "special_source";
	if(sizeof(all_inventory(item)) > 0)
		return "container";
	return "";
}

string query_auto_cleanup_category(object item)
{
	string material_type;
	if(!item)
		return "misc";
	if(item->is("combine_item")){
		material_type = item->query_for_material();
		if(material_type == "liandan")
			return "herb";
		if(material_type == "duanzao")
			return "mine";
	}
	return "misc";
}

int query_auto_cleanup_process_amount(object me,object item)
{
	int amount;
	int keep;
	string material_type;
	if(!me || !item)
		return 0;
	amount = query_non_equipment_destroy_item_amount(item);
	if(query_vip_level(me) < 3 || !item->is("combine_item"))
		return amount;
	material_type = item->query_for_material();
	if(material_type == "")
		return amount;
	keep = query_auto_cleanup_keep(me);
	if(amount <= keep)
		return 0;
	return amount-keep;
}

string query_auto_cleanup_reject_reason(object me,object item)
{
	string reason;
	string item_name;
	string category;
	reason = query_non_equipment_destroy_reject_reason(me,item);
	if(reason != "")
		return reason;
	if(query_vip_level(me) < 1)
		return "vip_required";
	item_name = item->query_name();
	if(query_auto_cleanup_name_mode(me,item_name) == "protect")
		return "protected_list";
	if(query_auto_cleanup_process_amount(me,item) <= 0)
		return "keep_amount";
	if(query_auto_cleanup_name_mode(me,item_name) == "force")
		return "";
	category = query_auto_cleanup_category(item);
	if(!query_auto_cleanup_category_enabled(me,category))
		return "category_disabled";
	return "";
}

array(object) query_auto_cleanup_candidates(object me)
{
	array(object) candidates = ({});
	if(!me || query_vip_level(me) < 1)
		return candidates;
	foreach(all_inventory(me),object item){
		if(query_auto_cleanup_reject_reason(me,item) == "")
			candidates += ({item});
	}
	return candidates;
}

array(object) query_non_equipment_destroy_candidates(object me)
{
	array(object) candidates = ({});
	if(!me)
		return candidates;
	foreach(all_inventory(me),object item){
		if(query_non_equipment_destroy_reject_reason(me,item) == "")
			candidates += ({item});
	}
	return candidates;
}

mapping(string:mixed) query_non_equipment_destroy_preview(object me)
{
	mapping(string:int) grouped = ([]);
	mapping(string:mixed) result = ([
		"object_count":0,
		"item_count":0,
		"names":({}),
	]);
	array(object) candidates;
	if(!me)
		return result;
	candidates = query_non_equipment_destroy_candidates(me);
	foreach(candidates,object item){
		string item_name = item->query_name_cn();
		int amount = query_non_equipment_destroy_item_amount(item);
		result["object_count"] = (int)result["object_count"]+1;
		result["item_count"] = (int)result["item_count"]+amount;
		grouped[item_name] = (int)grouped[item_name]+amount;
	}
	foreach(grouped;string item_name;int amount)
		result["names"] += ({item_name+"×"+amount});
	return result;
}

int should_auto_destroy_non_equipment(object me)
{
	if(!me || me->in_combat ||
	   !query_auto_destroy_non_equipment_enabled(me))
		return 0;
	if(query_backpack_percent(me) < query_auto_cleanup_trigger_percent(me))
		return 0;
	return sizeof(query_auto_cleanup_candidates(me)) > 0;
}

mapping(string:mixed) perform_non_equipment_destroy(object me,string source)
{
	mapping(string:mixed) result = ([
		"object_count":0,
		"item_count":0,
		"names":({}),
		"reason":"",
	]);
	array(object) candidates;
	int auto_mode;
	if(!me)
		return result;
	if(me->in_combat){
		result["reason"] = "in_combat";
		return result;
	}
	auto_mode = source == "autofight" ? 1 : 0;
	if(!auto_mode)
		source = "manual";
	if(auto_mode){
		if(!query_auto_destroy_non_equipment_enabled(me)){
			result["reason"] = "vip_required";
			return result;
		}
		candidates = query_auto_cleanup_candidates(me);
	}
	else
		candidates = query_non_equipment_destroy_candidates(me);
	foreach(candidates,object item){
		string item_name;
		string item_path;
		string now;
		int amount;
		if(auto_mode){
			if(query_auto_cleanup_reject_reason(me,item) != "")
				continue;
		}
		else if(query_non_equipment_destroy_reject_reason(me,item) != "")
			continue;
		item_name = item->query_name_cn();
		item_path = (file_name(item)/"#")[0];
		if(auto_mode)
			amount = query_auto_cleanup_process_amount(me,item);
		else
			amount = query_non_equipment_destroy_item_amount(item);
		if(amount <= 0)
			continue;
		result["object_count"] = (int)result["object_count"]+1;
		result["item_count"] = (int)result["item_count"]+amount;
		result["names"] += ({item_name+"×"+amount});
		now = ctime(time());
		ASYNC_IOD->append_log(ROOT+"/log/non_equipment_destroy.log",
			now[0..sizeof(now)-2]+" "+me->query_name_cn()+"("+
			me->query_name()+") "+source+" 销毁 "+item_name+" "+
			item_path+" 数量"+amount+"\n");
		if(auto_mode && item->is("combine_item") &&
		   amount < item->amount)
			item->amount -= amount;
		else
			item->remove();
	}
	return result;
}

int query_auto_store_batch_size(object me)
{
	int vip_level;
	vip_level = query_vip_level(me);
	if(vip_level >= 4)
		return 8;
	if(vip_level == 3)
		return 4;
	if(vip_level == 2)
		return 2;
	return 1;
}

int query_auto_storage_free_slots(object me)
{
	int maximum;
	int used;
	if(!me)
		return 0;
	maximum = me->query_cangku_size();
	used = me->packaged_items ? sizeof(me->packaged_items) : 0;
	if(maximum <= used)
		return 0;
	return maximum-used;
}

int should_auto_store_non_equipment(object me)
{
	if(!me || me->in_combat ||
	   !query_auto_store_non_equipment_enabled(me))
		return 0;
	if(query_auto_storage_free_slots(me) <= 0)
		return 0;
	if(query_backpack_percent(me) < query_auto_cleanup_trigger_percent(me))
		return 0;
	return sizeof(query_auto_cleanup_candidates(me)) > 0;
}

mapping(string:mixed) perform_auto_store_non_equipment(object me)
{
	mapping(string:mixed) result = ([
		"object_count":0,
		"item_count":0,
		"names":({}),
		"reason":"",
	]);
	array(object) candidates;
	int batch_size;
	int maximum;
	if(!me || me->in_combat)
		return result;
	if(!query_auto_store_non_equipment_enabled(me)){
		result["reason"] = "vip_required";
		return result;
	}
	if(query_auto_storage_free_slots(me) <= 0){
		result["reason"] = "warehouse_full";
		return result;
	}
	candidates = query_auto_cleanup_candidates(me);
	batch_size = query_auto_store_batch_size(me);
	maximum = me->query_cangku_size();
	for(int i = 0;i < sizeof(candidates) &&
	   (int)result["object_count"] < batch_size;i++){
		object item;
		object storage_item;
		string item_name;
		string item_path;
		string now;
		int amount;
		int package_error;
		item = candidates[i];
		if(query_auto_cleanup_reject_reason(me,item) != "")
			continue;
		if(query_auto_storage_free_slots(me) <= 0){
			result["reason"] = "warehouse_full";
			break;
		}
		item_name = item->query_name_cn();
		item_path = (file_name(item)/"#")[0];
		amount = query_auto_cleanup_process_amount(me,item);
		if(amount <= 0)
			continue;
		storage_item = item;
		if(item->is("combine_item") && amount < item->amount){
			storage_item = clone(item_path);
			storage_item->amount = amount;
		}
		package_error = me->packaged(storage_item,maximum);
		if(package_error){
			if(storage_item != item)
				storage_item->remove();
			result["reason"] = "warehouse_full";
			break;
		}
		if(storage_item != item){
			item->amount -= amount;
			storage_item->remove();
		}
		else
			item->remove();
		result["object_count"] = (int)result["object_count"]+1;
		result["item_count"] = (int)result["item_count"]+amount;
		result["names"] += ({item_name+"×"+amount});
		now = ctime(time());
		ASYNC_IOD->append_log(ROOT+"/log/autofight_storage.log",
			now[0..sizeof(now)-2]+" "+me->query_name_cn()+"("+
			me->query_name()+") 自动存仓 "+item_name+" "+item_path+
			" 数量"+amount+"\n");
	}
	return result;
}

void start_autofight(object me)
{
	string userid;
	if(!me)
		return;
	initialize_player(me);
	me["/tmp/autofight_last_charge"] = time();
	userid=normalize_server_autofight_userid((string)me->query_name());
	if(userid!="")
		server_autofight_charge_owners[userid]=me;
	me["/tmp/autofight_no_target_ticks"] = 0;
	me["/tmp/autofight_previous_room"] = "";
	clear_failed_loot(me);
	me["/tmp/autofight_first_death_time"] = 0;
	me["/tmp/autofight_death_count"] = 0;
	me["/tmp/autofight_quota_warned"] = 0;
	reset_scan_state(me);
	ensure_auto_skill(me);
	me->set_autofight("enable");
	ensure_server_autofight_tick(me);
}

void stop_autofight(object me)
{
	object env;
	string return_path;
	if(!me)
		return;
	cancel_server_autofight_tick(me);
	me["/tmp/autofight_last_charge"] = 0;
	me["/tmp/autofight_no_target_ticks"] = 0;
	me["/tmp/autofight_previous_room"] = "";
	me["/tmp/autofight_resting"] = 0;
	clear_failed_loot(me);
	reset_scan_state(me);
	me->set_autofight("disable");
	// 停止挂机后不把玩家困在无出口的临时分流房。战斗中不强制移动，
	// 等战斗结束后仍可手动飞行，空实例也会由定时清理器回收。
	env=environment(me);
	if(env && (int)env["/tmp/autofight_overflow"]==1 && !me->in_combat){
		return_path=(string)env["/tmp/autofight_overflow_path"];
		if(return_path!=""){
			me->move(ROOT+"/gamelib/d/"+return_path);
			me->reset_view();
		}
	}
}

int charge_time(object me)
{
	string userid;
	int now;
	int last;
	int elapsed;
	int left;
	if(!me)
		return 0;
	initialize_player(me);
	now = time();
	userid=normalize_server_autofight_userid((string)me->query_name());
	if(userid=="" || server_autofight_charge_owners[userid]!=me){
		if(userid!="")
			server_autofight_charge_owners[userid]=me;
		me["/tmp/autofight_last_charge"] = now;
		return query_time_left(me);
	}
	last = (int)me["/tmp/autofight_last_charge"];
	if(last <= 0 || last > now){
		me["/tmp/autofight_last_charge"] = now;
		return query_time_left(me);
	}
	elapsed = now-last;
	if(elapsed <= 0)
		return query_time_left(me);
	// 如果距上次扣费超过 30 秒，说明玩家离线/浏览器后台节流/网络断开，
	// 这段时间没有实际挂机（没杀怪没涨经验），不应消耗每日时间。
	if(elapsed > 30){
		me["/tmp/autofight_last_charge"] = now;
		return query_time_left(me);
	}
	left = query_time_left(me)-elapsed;
	if(left < 0)
		left = 0;
	me["/plus/autofight_time_left"] = left;
	me["/tmp/autofight_last_charge"] = now;
	return left;
}

string query_start_block_reason(object me)
{
	object env;
	if(!me)
		return "玩家对象不存在";
	initialize_player(me);
	if(me->is("npc"))
		return "NPC不能开启自动挂机";
	env = environment(me);
	if(!env)
		return "你当前不在有效地图中";
	if(me->is("ghost") || me->get_cur_life() <= 0)
		return "死亡或灵魂状态不能开启自动挂机";
	if((int)me["/plus/random_rcd"] > 0)
		return "请先完成当前的安全验证";
	if(query_time_left(me) <= 0)
		return query_quota_exhausted_message(me);
	consolidate_gathered_materials(me);
	if(query_loot_enabled(me) && me->if_over_easy_load()){
		if(query_auto_store_non_equipment_enabled(me) &&
		   query_auto_storage_free_slots(me) > 0 &&
		   sizeof(query_auto_cleanup_candidates(me)))
			return "";
		if(query_auto_destroy_non_equipment_enabled(me) &&
		   sizeof(query_auto_cleanup_candidates(me)))
			return "";
		if(query_auto_sell_material(me))
			return "";
		if(query_auto_sell_enabled(me) &&
		   sizeof(query_auto_sell_candidates(me)))
			return "";
		if(query_auto_sell_mode(me) != "off")
			return "背包已满，智能清包没有找到符合当前规则的装备";
		return "背包已满，请整理背包后再开启";
	}
	return "";
}

string query_runtime_block_reason(object me)
{
	string death_loop;
	if(!me)
		return query_start_block_reason(me);
	death_loop = query_death_loop_block_reason(me);
	if(death_loop != "")
		return death_loop;
	return query_start_block_reason(me);
}

// 死亡循环保护：5 分钟窗口内累计死亡 N 次判定为循环（卡复活点回挂机点
// 又被打死）。VIP 自动复活（百炼复苏/灵契共鸣）让循环几乎不中断，但装备
// 耐久会持续掉，玩家可能挂机半小时回来发现装备全坏。这里在 fight_die
// 里累计，在 query_runtime_block_reason 里拦截。
private int death_loop_window_seconds() { return 300; }   // 5 分钟
private int death_loop_threshold() { return 3; }          // 3 次死亡

void record_afk_death(object me)
{
	int now;
	int first;
	int count;
	if(!me || !functionp(me->query_autofight) ||
	   me->query_autofight() != "enable")
		return;
	now = time();
	first = (int)me["/tmp/autofight_first_death_time"];
	count = (int)me["/tmp/autofight_death_count"];
	// 窗口外重置
	if(first <= 0 || now-first > death_loop_window_seconds()){
		me["/tmp/autofight_first_death_time"] = now;
		me["/tmp/autofight_death_count"] = 1;
		return;
	}
	count += 1;
	me["/tmp/autofight_death_count"] = count;
}

string query_death_loop_block_reason(object me)
{
	int now;
	int first;
	int count;
	if(!me)
		return "";
	now = time();
	first = (int)me["/tmp/autofight_first_death_time"];
	count = (int)me["/tmp/autofight_death_count"];
	if(first <= 0 || count < death_loop_threshold())
		return "";
	// 窗口内死亡次数达到阈值
	if(now-first <= death_loop_window_seconds())
		return "5分钟内死亡"+(string)count+"次，自动停止以防死亡循环（装备耐久会持续损耗）";
	// 窗口已过，清空
	me["/tmp/autofight_first_death_time"] = 0;
	me["/tmp/autofight_death_count"] = 0;
	return "";
}

void reset_afk_death_counter(object me)
{
	if(!me)
		return;
	me["/tmp/autofight_first_death_time"] = 0;
	me["/tmp/autofight_death_count"] = 0;
}

int should_recover_life(object me)
{
	int life;
	int life_max;
	int percent;
	if(!me)
		return 0;
	life = me->get_cur_life();
	life_max = me->query_life_max();
	percent = query_hp_percent(me);
	if(life <= 0 || life_max <= 0)
		return 0;
	return life*100 < life_max*percent;
}

int should_recover_mana(object me)
{
	int mana;
	int mana_max;
	int percent;
	if(!me)
		return 0;
	mana = me->get_cur_mofa();
	mana_max = me->query_mofa_max();
	percent = query_mana_percent(me);
	if(percent <= 0 || mana_max <= 0)
		return 0;
	return mana*100 < mana_max*percent;
}

mapping(string:mixed) query_training_route(object me)
{
	mapping(string:mixed) route;
	string race;
	string path;
	int level;
	if(!me)
		return ([]);
	level = me->query_level();
	race = me->query_raceId();
	if(level>=ENDGAME_MAP_MIN_LEVEL){
		return attach_training_route_pool(([
			"max":MAX_LEVEL,
			"level":level>MAX_LEVEL ? MAX_LEVEL : level,
			"name":"九霄界境巅峰历练",
			"path":"jiuxiaojiejing/jiuxiaotianmen",
		]));
	}
	if(level>=70){
		path = "plxianjing/chilingxiaolu";
		if(race=="monst")
			path = "plxianjing/chiyuxiaolu";
		else if(race=="third")
			path = "penglaihuanjing/qiushuangxiaojing";
		return attach_training_route_pool(([
			"max":MAX_LEVEL,
			"level":level>MAX_LEVEL ? MAX_LEVEL : level,
			"name":"动态同级历练",
			"path":path,
		]));
	}
	if(level<1)
		level = 1;
	if(!training_route_cache[race])
		race = "third";
	route = training_route_cache[race][level];
	if(route)
		return copy_value(route);
	return ([]);
}

array(string) query_training_route_paths(object me)
{
	mapping(string:mixed) route=query_training_route(me);
	array(string) paths=(array(string))route["paths"];
	if(!paths)
		return ({});
	return copy_value(paths);
}

private int query_training_room_capacity(object me)
{
	if(me && me->query_level()>=70 &&
	   me->query_level()<ENDGAME_MAP_MIN_LEVEL)
		return AUTOFIGHT_DYNAMIC_ROOM_CAPACITY;
	return AUTOFIGHT_PUBLIC_ROOM_CAPACITY;
}

private int query_stable_training_offset(object me,int size)
{
	string userid;
	int value=0;
	if(!me || size<=0)
		return 0;
	userid=(string)me->query_name();
	for(int i=0;i<sizeof(userid);i++)
		value=(value+userid[i]*(i+1))%size;
	return value;
}

private mapping(string:int) query_public_training_occupancy()
{
	mapping(string:int) occupancy=([]);
	array(object) players=users(1);
	for(int i=0;i<sizeof(players);i++){
		object env;
		string path;
		if(!players[i])
			continue;
		env=environment(players[i]);
		if(!env || (int)env["/tmp/autofight_overflow"]==1)
			continue;
		path=query_current_room_path(players[i]);
		if(path!="")
			occupancy[path]=(int)occupancy[path]+1;
	}
	return occupancy;
}

mapping(string:mixed) query_balanced_training_route(object me,
	void|int avoid_current)
{
	mapping(string:mixed) route=query_training_route(me);
	mapping(string:int) occupancy;
	array(string) paths;
	string current;
	string selected="";
	object env;
	int capacity;
	int min_count=-1;
	int all_full=1;
	int offset;
	if(!route || !sizeof(route))
		return ([]);
	paths=(array(string))route["paths"];
	if(!paths || !sizeof(paths))
		return route;
	occupancy=query_public_training_occupancy();
	current=query_current_room_path(me);
	env=environment(me);
	capacity=query_training_room_capacity(me);
	offset=query_stable_training_offset(me,sizeof(paths));
	for(int i=0;i<sizeof(paths);i++){
		string candidate=paths[(offset+i)%sizeof(paths)];
		int count=(int)occupancy[candidate];
		if(avoid_current && sizeof(paths)>1 && candidate==current)
			continue;
		if(count<capacity)
			all_full=0;
		if(min_count<0 || count<min_count){
			selected=candidate;
			min_count=count;
		}
	}
	if(selected=="")
		selected=(string)route["path"];
	route["path"]=selected;
	route["selected_occupancy"]=(int)occupancy[selected];
	route["capacity"]=capacity;
	route["all_full"]=all_full;
	route["pool_size"]=sizeof(paths);
	// 临时分流房没有出口。它连续空图后必须回到公共练级房恢复，
	// 即使公共房当前满员也不能再次套入另一个可能空置的实例。
	if(avoid_current && env &&
	   (int)env["/tmp/autofight_overflow"]==1)
		route["recovering_overflow"]=1;
	return route;
}

private int is_training_pool_path(mapping(string:mixed) route,string path)
{
	array(string) paths;
	if(!route || !path || path=="")
		return 0;
	paths=(array(string))route["paths"];
	if(!paths)
		return path==(string)route["path"];
	return search(paths,path)!=-1;
}

string query_current_room_path(object me)
{
	object env;
	string path;
	string prefix;
	if(!me)
		return "";
	env = environment(me);
	if(!env)
		return "";
	path = (file_name(env)/"#")[0];
	prefix = ROOT+"/gamelib/d/";
	if(has_prefix(path,prefix))
		return path[sizeof(prefix)..];
	return path;
}

private int count_players_in_training_room(object room)
{
	array(object) all;
	int count=0;
	if(!room)
		return 0;
	all=all_inventory(room);
	for(int i=0;i<sizeof(all);i++){
		if(all[i] && all[i]->is("player") && !all[i]->is("npc"))
			count++;
	}
	return count;
}

private int count_active_autofight_players_in_room(object room)
{
	array(object) all;
	int count=0;
	if(!room)
		return 0;
	all=all_inventory(room);
	for(int i=0;i<sizeof(all);i++){
		if(all[i] && all[i]->is("player") && !all[i]->is("npc") &&
		   functionp(all[i]->query_autofight) &&
		   all[i]->query_autofight()=="enable")
			count++;
	}
	return count;
}

private int evacuate_inactive_overflow_players(object room,string path)
{
	array(object) all;
	int moved=0;
	if(!room || !path || path=="")
		return 0;
	all=all_inventory(room);
	for(int i=0;i<sizeof(all);i++){
		if(!all[i] || !all[i]->is("player") || all[i]->is("npc") ||
		   all[i]->in_combat)
			continue;
		if(functionp(all[i]->query_autofight) &&
		   all[i]->query_autofight()=="enable")
			continue;
		int moved_one;
		mixed move_err = catch {
			moved_one = all[i]->move(ROOT+"/gamelib/d/"+path);
		};
		if(!move_err && moved_one){
			all[i]->reset_view();
			moved++;
		}
	}
	return moved;
}

private string query_overflow_pool_key(object me,
	mapping(string:mixed) route)
{
	string key=(string)route["pool_key"];
	if(key=="")
		key=(string)route["path"];
	// 70-989 级房间会把普通怪动态到进入者等级，必须按等级隔离，
	// 避免不同等级玩家共享实例时互相刷出不合适的目标。
	if(me && me->query_level()>=70 &&
	   me->query_level()<ENDGAME_MAP_MIN_LEVEL)
		key+="#level"+(string)me->query_level();
	return key;
}

private int query_overflow_capacity(object me)
{
	if(me && me->query_level()>=70 &&
	   me->query_level()<ENDGAME_MAP_MIN_LEVEL)
		return 1;
	return AUTOFIGHT_OVERFLOW_ROOM_CAPACITY;
}

private void schedule_overflow_cleanup()
{
	if(autofight_overflow_cleanup_scheduled ||
	   autofight_overflow_room_count<=0)
		return;
	autofight_overflow_cleanup_scheduled=1;
	call_out(cleanup_autofight_overflow_rooms,
		AUTOFIGHT_OVERFLOW_CLEANUP_SECONDS);
}

private void destroy_autofight_overflow_room(object room)
{
	array(object) all;
	if(!room)
		return;
	all=all_inventory(room);
	for(int i=0;i<sizeof(all);i++)
		if(all[i])
			destruct(all[i]);
	destruct(room);
}

private void cleanup_autofight_overflow_rooms()
{
	int now=time();
	array(string) pool_keys=indices(autofight_overflow_rooms);
	autofight_overflow_cleanup_scheduled=0;
	for(int i=0;i<sizeof(pool_keys);i++){
		array(mapping(string:mixed)) entries=
			autofight_overflow_rooms[pool_keys[i]] || ({});
		array(mapping(string:mixed)) kept=({});
		for(int j=0;j<sizeof(entries);j++){
			object room=entries[j]["room"];
			int player_count=count_players_in_training_room(room);
			int active_count=count_active_autofight_players_in_room(room);
			if(room && active_count>0){
				entries[j]["last_used"]=now;
				kept+=({entries[j]});
				continue;
			}
			if(room && player_count>0){
				evacuate_inactive_overflow_players(room,
					(string)entries[j]["path"]);
				player_count=count_players_in_training_room(room);
				if(player_count>0){
					kept+=({entries[j]});
					continue;
				}
			}
			if(room && now-(int)entries[j]["last_used"]<
			   AUTOFIGHT_OVERFLOW_IDLE_SECONDS){
				kept+=({entries[j]});
				continue;
			}
			if(room)
				destroy_autofight_overflow_room(room);
			if(autofight_overflow_room_count>0)
				autofight_overflow_room_count--;
			autofight_overflow_destroyed++;
		}
		if(sizeof(kept))
			autofight_overflow_rooms[pool_keys[i]]=kept;
		else
			m_delete(autofight_overflow_rooms,pool_keys[i]);
	}
	schedule_overflow_cleanup();
}

private object|zero query_or_create_overflow_room(object me,
	mapping(string:mixed) route)
{
	string pool_key=query_overflow_pool_key(me,route);
	string path=(string)route["path"];
	array(mapping(string:mixed)) entries=
		autofight_overflow_rooms[pool_key] || ({});
	int capacity=query_overflow_capacity(me);
	object room;
	mixed err;
	// A clone has no reconstructable cross-worker arrival path. Let qge74hye
	// migrate the player to the static owner first; that owner may then split.
	if(path=="" || !MAP_WORKERD->local_worker_owns_room(
	   ROOT+"/gamelib/d/"+path))
		return 0;
	for(int i=0;i<sizeof(entries);i++){
		object room=entries[i]["room"];
		if(room && count_players_in_training_room(room)<capacity){
			entries[i]["last_used"]=time();
			return room;
		}
	}
	if(sizeof(entries)>=AUTOFIGHT_OVERFLOW_MAX_PER_POOL ||
	   autofight_overflow_room_count>=AUTOFIGHT_OVERFLOW_GLOBAL_LIMIT){
		autofight_overflow_limit_fallbacks++;
		return 0;
	}
	err=catch{
		room=clone(ROOT+"/gamelib/d/"+path);
	};
	if(err || !room)
		return 0;
	room["/tmp/autofight_overflow"]=1;
	room["/tmp/autofight_overflow_path"]=path;
	room->exits=([]);
	room->closed_exits=([]);
	room->opened_exits=([]);
	room->hidden_exits=([]);
	room->guarded_exits=([]);
	room->name_cn=(string)room->name_cn+"·挂机分流";
	room->desc="这里是自动挂机按负载临时开辟的独立修炼空间。\n";
	entries+=({([
		"room":room,
		"path":path,
		"created":time(),
		"last_used":time(),
	])});
	autofight_overflow_rooms[pool_key]=entries;
	autofight_overflow_room_count++;
	autofight_overflow_created++;
	schedule_overflow_cleanup();
	return room;
}

int move_to_training_route(object me,mapping(string:mixed) route)
{
	string path;
	object|zero room=0;
	object env;
	if(!me || !route || !sizeof(route) || me->in_combat)
		return 0;
	path=(string)route["path"];
	if(path=="")
		return 0;
	if((int)route["all_full"]==1 &&
	   (int)route["recovering_overflow"]!=1)
		room=query_or_create_overflow_room(me,route);
	if(!room){
		me->command("qge74hye "+path);
		if(query_current_room_path(me)==path){
			autofight_training_reroutes++;
			return 1;
		}
		return 0;
	}
	env=environment(me);
	int was_in_home=me->if_in_home();
	int moved;
	mixed move_err=catch { moved=me->move(room); };
	if(move_err || !moved || environment(me)!=room)
		return 0;
	if(was_in_home)
		HOMED->clear_user(me);
	if(env && !env->is("character") && !env->is("menu"))
		me->last_pos=file_name(env)-ROOT;
	me->m_delete_foruser("/tmp/tour_pos");
	me->reset_view();
	me->command("look");
	if(environment(me)==room){
		autofight_training_reroutes++;
		return 1;
	}
	return 0;
}

mapping query_autofight_overflow_status()
{
	return ([
		"rooms":autofight_overflow_room_count,
		"pools":sizeof(autofight_overflow_rooms),
		"global_limit":AUTOFIGHT_OVERFLOW_GLOBAL_LIMIT,
		"per_pool_limit":AUTOFIGHT_OVERFLOW_MAX_PER_POOL,
		"idle_seconds":AUTOFIGHT_OVERFLOW_IDLE_SECONDS,
		"created":autofight_overflow_created,
		"destroyed":autofight_overflow_destroyed,
		"limit_fallbacks":autofight_overflow_limit_fallbacks,
	]);
}

private int maybe_refresh_training_room_npcs(object me,object env)
{
	mapping(string:mixed) route;
	string current;
	int overflow_room;
	int active_players;
	int spawned;
	if(!me || !env || !functionp(env->refresh_autofight_normal_npcs))
		return 0;
	if(functionp(env->query_autofight_pressure_check_ready) &&
	   !env->query_autofight_pressure_check_ready())
		return 0;
	overflow_room=(int)env["/tmp/autofight_overflow"]==1;
	route=query_training_route(me);
	current=query_current_room_path(me);
	if(!overflow_room && !is_training_pool_path(route,current))
		return 0;
	active_players=count_players_in_training_room(env);
	spawned=env->refresh_autofight_normal_npcs(me,active_players,
		overflow_room);
	if(spawned>0)
		autofight_pressure_refills+=spawned;
	return spawned;
}

int can_auto_leave_current_room(object me)
{
	object env;
	string room_type;
	if(!me)
		return 0;
	env = environment(me);
	if(!env)
		return 0;
	room_type = env->query_room_type();
	if(room_type=="fb" || room_type=="home" ||
	   room_type=="city" || room_type=="town")
		return 0;
	return 1;
}

string query_rest_room(object me)
{
	if(!me)
		return "";
	if(me->query_raceId()=="monst")
		return "jinaodao/yuhuacunguangchang";
	return "congxianzhen/congxianzhenguangchang";
}

int query_is_resting(object me)
{
	if(!me)
		return 0;
	return (int)me["/tmp/autofight_resting"] == 1;
}

int begin_auto_rest(object me)
{
	if(!me || !query_auto_rest_enabled(me) ||
	   !can_auto_leave_current_room(me))
		return 0;
	me["/tmp/autofight_resting"] = 1;
	me["/tmp/autofight_rest_started"] = time();
	return 1;
}

void finish_auto_rest(object me)
{
	if(!me)
		return;
	me["/tmp/autofight_resting"] = 0;
	me["/tmp/autofight_rest_started"] = 0;
}

int query_route_ready(object me)
{
	int last;
	if(!me)
		return 0;
	last = (int)me["/tmp/autofight_last_route_time"];
	return last<=0 || time()-last>=AUTOFIGHT_ROUTE_COOLDOWN;
}

void record_route(object me,string path)
{
	if(!me)
		return;
	me["/tmp/autofight_last_route_time"] = time();
	me["/tmp/autofight_no_target_ticks"] = 0;
	me["/tmp/autofight_previous_room"] = "";
	me["/plus/autofight_last_route"] = path;
}

private int is_same_area(string current_path, string destination)
{
	array(string) current_parts;
	array(string) destination_parts;
	if(!current_path || !destination)
		return 0;
	current_path = (current_path/"#")[0];
	current_parts = current_path/"/";
	destination_parts = destination/"/";
	if(sizeof(current_parts) < 2 || sizeof(destination_parts) < 2)
		return 0;
	return current_parts[sizeof(current_parts)-2] ==
		destination_parts[sizeof(destination_parts)-2];
}

int should_route_to_training_area(object me,void|mapping target_snapshot)
{
	mapping(string:mixed) route;
	object env;
	string current;
	string destination;
	if(!me || !query_smart_route_enabled(me) ||
	   !can_auto_leave_current_room(me) || !query_route_ready(me))
		return 0;
	route = query_training_route(me);
	destination = (string)route["path"];
	if(destination=="")
		return 0;
	current = query_current_room_path(me);
	env=environment(me);
	if(env && (int)env["/tmp/autofight_overflow"]==1){
		if(target_snapshot && (int)target_snapshot["visible"]>0)
			return 1;
		if(!target_snapshot && query_visible_monster_count(me)>0 &&
		   !query_target(me))
			return 1;
		return (int)me["/tmp/autofight_no_target_ticks"]>=
			AUTOFIGHT_ROAM_NO_TARGET_TICKS;
	}
	if(is_training_pool_path(route,current)){
		if(target_snapshot && (int)target_snapshot["visible"]>0)
			return 1;
		if(!target_snapshot && query_visible_monster_count(me)>0 &&
		   !query_target(me))
			return 1;
		return (int)me["/tmp/autofight_no_target_ticks"]>=
			AUTOFIGHT_ROAM_NO_TARGET_TICKS;
	}
	// 同一区域也可能相差十几层。当前房间明明有怪却全部超出
	// 安全等级时，直接回到精确推荐层，避免在相邻楼层间随机游走。
	// 真正的空图仍交给区域巡游，保留原有刷新与防抖行为。
	if(is_same_area(current,destination)){
		if(target_snapshot && (int)target_snapshot["visible"]>0)
			return 1;
		if(!target_snapshot && query_visible_monster_count(me)>0 &&
		   !query_target(me))
			return 1;
		return (int)me["/tmp/autofight_no_target_ticks"]>=
			AUTOFIGHT_ROAM_NO_TARGET_TICKS;
	}
	return 1;
}

int record_no_target(object me)
{
	int ticks;
	if(!me)
		return 0;
	ticks = (int)me["/tmp/autofight_no_target_ticks"]+1;
	me["/tmp/autofight_no_target_ticks"] = ticks;
	return ticks;
}

void clear_no_target(object me)
{
	if(me)
		me["/tmp/autofight_no_target_ticks"] = 0;
}

void record_roam(object me)
{
	if(!me)
		return;
	me["/tmp/autofight_previous_room"] =
		query_current_room_path(me);
	me["/tmp/autofight_no_target_ticks"] = 0;
}

mapping(string:int) query_target_level_window(object me)
{
	mapping(string:mixed) route;
	int me_level;
	int minimum_level;
	int maximum_level;
	int route_level;
	if(!me)
		return (["minimum":1,"maximum":1]);
	me_level = me->query_level();
	maximum_level = me_level+2;
	minimum_level = 1;
	if(query_smart_route_enabled(me)){
		maximum_level = me_level;
		route = query_training_route(me);
		route_level = (int)route["level"];
		// 59级的固定路线位于60级怪区。只接受推荐路线恰好高1级的
		// 边界，不把智能挂机普遍放宽成可随意越级攻击。
		if(route_level == me_level+1)
			maximum_level = route_level;
		minimum_level = me_level-4;
		if(minimum_level<1)
			minimum_level = 1;
	}
	return ([
		"minimum":minimum_level,
		"maximum":maximum_level,
	]);
}

//“可见怪物”必须是挂机真正可以考虑攻击的野怪单位。
//方士三灵虽然继承 NPC，但它们是玩家随从；若计入可见怪数，
//只剩三灵的空图就会被误判为“有怪但不安全”并阻断换图。
private int is_visible_autofight_monster(object me,object ob)
{
	if(!me || !ob || ob==me)
		return 0;
	if(!ob->is("character") || !ob->is("npc"))
		return 0;
	if(ob->hind!=0 || ob->get_cur_life()<=0)
		return 0;
	if(functionp(ob->query_summon_type))
		return 0;
	if(functionp(ob->can_be_attacked) && !ob->can_be_attacked(me))
		return 0;
	if(!LOGICALZONED->can_action("combat",me,ob))
		return 0;
	return 1;
}

int query_visible_monster_count(object me)
{
	object env;
	array(object) all;
	int count;
	if(!me)
		return 0;
	env = environment(me);
	if(!env)
		return 0;
	all = all_inventory(env);
	count = 0;
	foreach(all,object ob){
		if(is_visible_autofight_monster(me,ob))
			count++;
	}
	return count;
}

private int is_valid_target(object me, object ob)
{
	mapping(string:int) level_window;
	string npc_type;
	string me_race;
	string npc_race;
	int npc_level;
	int minimum_level;
	int maximum_level;
	if(!is_visible_autofight_monster(me,ob))
		return 0;
	if(ob->_boss || ob->_tasknpc)
		return 0;
	npc_type = ob->query_npc_type();
	if(npc_type == "city_keeper" || npc_type == "city_guarder" ||
	   npc_type == "city_lord")
		return 0;
	me_race = me->query_raceId();
	npc_race = ob->query_raceId();
	if(me_race != "third" && me_race == npc_race)
		return 0;
	npc_level = ob->query_level();
	level_window = query_target_level_window(me);
	minimum_level = level_window["minimum"];
	maximum_level = level_window["maximum"];
	if(npc_level > maximum_level || npc_level < minimum_level)
		return 0;
	return 1;
}

object|zero query_target(object me)
{
	mapping snapshot = query_target_snapshot(me);
	return snapshot["target"];
}

mapping query_target_snapshot(object me)
{
	object env;
	object|zero best;
	array(object) all;
	int best_level;
	int visible;
	int total;
	int start;
	int scan_count;
	int visible_total;
	string room_identity;
	if(!me)
		return (["target":0,"visible":0,"scanned":0,"total":0,
			"deferred":0,"cycle_complete":1]);
	env = environment(me);
	if(!env || env->is("peaceful"))
		return (["target":0,"visible":0,"scanned":0,"total":0,
			"deferred":0,"cycle_complete":1]);
	if(me->query_level()<70)
		MUD_ROOMD->restore_low_level_room_npcs(me);
	maybe_refresh_training_room_npcs(me,env);
	all = all_inventory(env);
	total = sizeof(all);
	room_identity = file_name(env);
	if((string)me["/tmp/autofight_scan_cursor_room"]!=room_identity){
		me["/tmp/autofight_scan_cursor"] = 0;
		me["/tmp/autofight_scan_cursor_room"] = room_identity;
		me["/tmp/autofight_scan_visible_total"] = 0;
	}
	start = (int)me["/tmp/autofight_scan_cursor"];
	if(start<0 || start>=total)
		start = 0;
	if(start==0)
		me["/tmp/autofight_scan_visible_total"] = 0;
	scan_count = total-start;
	if(scan_count>AUTOFIGHT_SCAN_MAX_OBJECTS)
		scan_count = AUTOFIGHT_SCAN_MAX_OBJECTS;
	autofight_scan_count++;
	if(total>start+scan_count)
		autofight_scan_deferred_objects += total-start-scan_count;
	best_level = -1;
	for(int offset=0;offset<scan_count;offset++){
		object ob = all[start+offset];
		int npc_level;
		if(is_visible_autofight_monster(me,ob))
			visible++;
		if(!is_valid_target(me,ob))
			continue;
		npc_level = ob->query_level();
		if(npc_level > best_level){
			best = ob;
			best_level = npc_level;
		}
	}
	visible_total = (int)me["/tmp/autofight_scan_visible_total"]+visible;
	me["/tmp/autofight_scan_visible_total"] = visible_total;
	if(start+scan_count>=total)
		me["/tmp/autofight_scan_cursor"] = 0;
	else
		me["/tmp/autofight_scan_cursor"] = start+scan_count;
	return ([
		"target":best,
		"visible":visible_total,
		"scanned":scan_count,
		"total":total,
		"deferred":total-start-scan_count,
		"cycle_complete":start+scan_count>=total,
	]);
}

private int can_loot_item(object me, object ob)
{
	string owner;
	string name_cn;
	int protect_time;
	if(!me || !ob)
		return 0;
	if(!ob->is("item") || ob->is("npc"))
		return 0;
	// 矿脉和药株是采集源，不是普通掉落。熟练度不足时采集入口会
	// 跳过它们，拾取入口也必须跳过，避免把“原矿/原药株”捡进背包。
	if(functionp(ob->query_source_type))
		return 0;
	if(functionp(ob->query_item_canGet) && ob->query_item_canGet() != 1)
		return 0;
	if(ob->query_name() == "corpse")
		return 0;
	name_cn = ob->query_name_cn();
	if(name_cn && (search(name_cn,"尸体") != -1 ||
	   search(name_cn,"骸骨") != -1))
		return 0;
	owner = ob->item_whoCanGet;
	protect_time = (int)ob->item_TimewhoCanGet;
	if(owner && owner != "" && owner != "1" &&
	   owner != me->query_name() && owner != me->query_term()){
		if(time()-protect_time < 120)
			return 0;
	}
	return 1;
}

void clear_failed_loot(object me)
{
	string userid;
	if(!me)
		return;
	userid=normalize_server_autofight_userid((string)me->query_name());
	if(userid!="")
		m_delete(autofight_failed_loot_runtime,userid);
	// Remove archives written by the historical implementation as well.
	me["/tmp/autofight_failed_loot"] = 0;
	me["/tmp/autofight_failed_loot_room"] = 0;
	me["/tmp/autofight_failed_loot_retry"] = 0;
}

void record_failed_loot(object me,object item)
{
	string userid;
	if(!me || !item)
		return;
	userid=normalize_server_autofight_userid((string)me->query_name());
	if(userid=="")
		return;
	autofight_failed_loot_runtime[userid]=([
		"item":item,
		"room":environment(me),
		"retry_at":time()+AUTOFIGHT_LOOT_RETRY_SECONDS,
	]);
}

int query_loot_temporarily_suppressed(object me,object item)
{
	string userid;
	mapping runtime;
	object|zero failed;
	object|zero failed_room;
	if(!me || !item)
		return 0;
	userid=normalize_server_autofight_userid((string)me->query_name());
	runtime=userid!="" ? autofight_failed_loot_runtime[userid] : 0;
	if(!mappingp(runtime))
		return 0;
	failed = runtime["item"];
	failed_room = runtime["room"];
	if(!failed || failed_room!=environment(me) ||
	   environment(failed)!=environment(me) ||
	   (int)runtime["retry_at"]<=time()){
		clear_failed_loot(me);
		return 0;
	}
	return failed==item;
}

object|zero query_loot_item(object me)
{
	object env;
	array(object) all;
	if(!me || !query_loot_enabled(me))
		return 0;
	env = environment(me);
	if(!env)
		return 0;
	all = query_bounded_scan_slice(me,all_inventory(env,me),
		"/tmp/autofight_loot_scan_cursor");
	foreach(all,object ob){
		if(can_loot_item(me,ob) &&
		   !query_loot_temporarily_suppressed(me,ob) &&
		   !me->if_over_load(ob))
			return ob;
	}
	return 0;
}

private int is_matching_recovery_item(object me,object item,string kind)
{
	mapping supply;
	if(!me || !item || item->amount <= 0 || item->eat_flag != 1)
		return 0;
	if(me->query_level() < item->level_limit)
		return 0;
	if(!item->race_limit[me->query_raceId()] ||
	   !sizeof(item->race_limit[me->query_raceId()]))
		return 0;
	if(!item->profe_limit[me->query_profeId()] ||
	   !sizeof(item->profe_limit[me->query_profeId()]))
		return 0;
	supply = item->add_supplay;
	if(!supply || !sizeof(supply))
		return 0;
	if(kind == "life")
		return functionp(item->eat) && (int)supply["life_supply"] > 0;
	if(kind == "mana")
		return functionp(item->drink) && (int)supply["mofa_supply"] > 0;
	return 0;
}

object|zero query_recovery_item(object me, string kind)
{
	string setting;
	array(object) all;
	if(!me)
		return 0;
	initialize_player(me);
	if(kind == "life")
		setting = (string)me["/plus/autofight_food"];
	else
		setting = (string)me["/plus/autofight_water"];
	all = all_inventory(me);
	foreach(all,object item){
		if(setting != "auto" && setting != "" &&
		   item->query_name() != setting)
			continue;
		if(is_matching_recovery_item(me,item,kind))
			return item;
	}
	if(setting != "auto" && setting != ""){
		foreach(all,object item){
			if(is_matching_recovery_item(me,item,kind))
				return item;
		}
	}
	return 0;
}

object|zero query_recovery_item_with_newbie_supply(object me,string kind)
{
	object|zero item;
	mapping result;
	if(!me)
		return 0;
	item = query_recovery_item(me,kind);
	if(item)
		return item;
	if(me->query_level()>NEWBIED->query_newbie_supply_max_level())
		return 0;
	result = NEWBIED->claim_newbie_supplies(me);
	if(result["code"]!=1)
		return 0;
	return query_recovery_item(me,kind);
}

int query_object_count(object ob, object env)
{
	array(object) all;
	int count;
	if(!ob || !env)
		return 0;
	all = all_inventory(env);
	count = 0;
	foreach(all,object item){
		if(item == ob)
			return count;
		if(item->query_name() == ob->query_name())
			count++;
	}
	return 0;
}

string query_safe_exit(object me)
{
	object env;
	array(string) exits;
	array(string) safe_exits;
	string current_path;
	string previous_room;
	string room_prefix;
	// 区域巡游是手动模式；智能寻路也应在推荐练级区空图时
	// 自动换到相邻地图，避免默认设置下永久等待刷新。
	if(!me || (!query_roam_enabled(me) &&
	   !query_smart_route_enabled(me)))
		return "";
	if((int)me["/tmp/autofight_no_target_ticks"] <
	   AUTOFIGHT_ROAM_NO_TARGET_TICKS)
		return "";
	if(!can_auto_leave_current_room(me))
		return "";
	env = environment(me);
	if(!env || !env->exits || !sizeof(env->exits))
		return "";
	current_path = file_name(env);
	previous_room = (string)me["/tmp/autofight_previous_room"];
	room_prefix = ROOT+"/gamelib/d/";
	exits = indices(env->exits);
	safe_exits = ({});
	foreach(exits,string direction){
		string destination;
		string destination_path;
		destination = (string)env->exits[direction];
		if(!destination || destination == "")
			continue;
		if(env->closed_exits[direction])
			continue;
		if(env->hidden_exits[direction])
			continue;
		if(env->guarded_exits[direction])
			continue;
		destination_path = (destination/"#")[0];
		if(has_prefix(destination_path,room_prefix))
			destination_path =
				destination_path[sizeof(room_prefix)..];
		if(previous_room && destination_path == previous_room &&
		   (int)me["/tmp/autofight_no_target_ticks"] <
		   AUTOFIGHT_ROAM_BACKTRACK_TICKS)
			continue;
		if(is_same_area(current_path,destination))
			safe_exits += ({direction});
	}
	if(!sizeof(safe_exits))
		return "";
	return safe_exits[random(sizeof(safe_exits))];
}
