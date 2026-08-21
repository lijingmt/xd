#!/usr/bin/env pike
/** Map-worker placement, fencing, migration and admin safety regression tests. */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	werror("\n[地图Worker %d] %s\n",results["total"],name);
	if(valid){
		results["passed"]++;
		werror("  ✓ 通过\n");
	}
	else{
		results["failed"]++;
		werror("  ✗ 失败: %s\n",reason);
	}
}

int source_has(string path,string needle)
{
	string source = Stdio.read_file(ROOT+path);
	return source && search(source,needle)!=-1;
}

int main()
{
	program daemon_program = (program)(ROOT+
		"/gamelib/single/daemons/map_workerd.pike");
	object daemon = daemon_program();
	string prefix = "t"+(string)time()+(string)random(100000);
	array(string) worker_ids = ({prefix+"w1",prefix+"w2",prefix+"w3"});
	array(mapping) registrations = ({});
	mapping placement;
	mapping lease;
	mapping handoff;
	mapping committed;
	mapping status;
	string source_worker;
	string target_worker;
	string source_affinity = "test/source/"+prefix;
	string target_affinity = "testtarget"+prefix;
	string target_room_path = "/gamelib/d/"+target_affinity+"/room";
	string userid = "xd98"+prefix;
	string target_user = "xd98"+prefix+"to";
	string request_id = prefix+"handoff";
	string message_id = prefix+"message";
	string transaction_id = prefix+"escrow";
	string item_id =
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
	string item_digest =
		"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
	string error_desc = "";
	int valid;

	werror("\n========== 地图 Worker 架构测试 ==========\n");
	mixed err = catch {
		check("队伍结构事件保留七天且普通聊天仍使用短期窗口",
			daemon->query_local_social_event_ttl("team_snapshot")==604800 &&
			daemon->query_local_social_event_ttl("team_invite")==604800 &&
			daemon->query_local_social_event_ttl("world_broadcast")==86400 &&
			daemon->query_local_social_event_ttl("team_chat")==300 &&
			daemon->query_local_social_event_ttl("channel_chat")==300,
			"队伍快照可能在节点维护期间过期，或普通聊天无限堆积");
		mapping account_save_capability = ([
			"state":"running","kind":"account",
			"account_owner":"xd98accountowner",
			"account_character_save_userid":"xd98accountownerc1a2b3c4d5",
		]);
		check("新角色首次存档能力严格绑定账号、本次请求和唯一子档案",
			daemon->test_local_account_character_save_capability(
				account_save_capability,"xd98accountowner",
				"xd98accountownerc1a2b3c4d5") &&
			!daemon->test_local_account_character_save_capability(
				account_save_capability,"xd98accountowner",
				"xd98accountownerc2ffffffff") &&
			!daemon->test_local_account_character_save_capability(
				account_save_capability,"xd98otheraccount",
				"xd98accountownerc1a2b3c4d5") &&
			!daemon->test_local_account_character_save_capability(([
				"state":"running","kind":"account",
				"account_owner":"xd98accountowner",
				"account_character_save_userid":"xd98victim",
			]),"xd98accountowner","xd98victim") &&
			!daemon->test_local_account_character_save_capability(([
				"state":"running","kind":"account",
				"account_owner":"xd98accountowner",
			]),"xd98accountowner","xd98accountownerc1a2b3c4d5") &&
			!daemon->test_local_account_character_save_capability(([
				"state":"running","kind":"account",
				"account_owner":"xd98accountowner",
				"account_character_save_userid":
					"xd98accountownerc1a2b3c4d5",
				"account_character_save_consumed_userid":
					"xd98accountownerc1a2b3c4d5",
			]),"xd98accountowner","xd98accountownerc1a2b3c4d5") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"if(bound_userid==userid)") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"stringp(\n\t\trequest[\"account_character_save_userid\"])") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"account_character_save_already_consumed") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"has_prefix(userid,account_owner+\"c\")") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"account_character_save_consumed_userid\"] = userid") &&
			source_has("/gamelib/clone/user.pike",
				"consume_local_account_character_save_fence"),
			"无租约新档可能越权保存兄弟人物、复用能力或继续被保存栅栏误拒");

		check("普通地图按一级目录归属，家园与限时活动各自保持单一一致性域",
			daemon->query_affinity_key(
				ROOT+"/gamelib/d/wugongdong/wugongchao#12","")==
				"wugongdong" &&
				daemon->query_affinity_key(
					"/gamelib/d/home/template/main","xd98home1")==
					"home" &&
				daemon->query_affinity_key(
					"/gamelib/d/ninggedian/qianxuehu","")=="home" &&
			daemon->query_affinity_key(
				"/gamelib/d/timed_event/event_room#2",
				"tianheng|2026-08-09|group1")==
				"timed_event" &&
			daemon->query_affinity_key("../../etc/passwd","")=="",
			"静态房间被拆分、实例未分片或路径穿越未拒绝");

		check("S1公共营地、剧情章节与三组中立猎场可分散到多个worker",
			daemon->query_affinity_key(
				"/gamelib/d/illusion_s1/moon_gate.pike","")==
				"illusion_s1:hub" &&
			daemon->query_affinity_key(
				"/gamelib/d/illusion_s1/silver_path.pike","")==
				"illusion_s1:silver" &&
			daemon->query_affinity_key(
				"/gamelib/d/illusion_s1/fog_forest.pike","")==
				daemon->query_affinity_key(
					"/gamelib/d/illusion_s1/mirror_lake.pike","") &&
			daemon->query_affinity_key(
				"/gamelib/d/illusion_s1/broken_observatory.pike","")==
				"illusion_s1:ruins" &&
			daemon->query_affinity_key(
				"/gamelib/d/illusion_s1/newmoon_altar.pike","")==
				"illusion_s1:depths" &&
			daemon->query_affinity_key(
				"/gamelib/d/illusion_s1/moon_dew_field.pike","")==
				"illusion_s1:hunt_a" &&
			daemon->query_affinity_key(
				"/gamelib/d/illusion_s1/silver_reed_bank.pike","")==
				"illusion_s1:hunt_b" &&
			daemon->query_affinity_key(
				"/gamelib/d/illusion_s1/starlight_slope.pike","")==
				"illusion_s1:hunt_c" &&
			daemon->query_affinity_key(
				"/gamelib/d/illusion_s1/future_room.pike","")==
				"illusion_s1:frontier",
			"S1仍可能整区挤在一个worker，或同房间映射不稳定");

		check("跨Worker静态房间校验兼容Pike后缀且不放宽到其他房间",
			daemon->canonical_static_room_location(
				"/gamelib/d/illusion_s1/fog_forest.pike")==
					"/gamelib/d/illusion_s1/fog_forest" &&
			daemon->static_room_locations_match(
				"/gamelib/d/illusion_s1/fog_forest",
				"/gamelib/d/illusion_s1/fog_forest.pike") &&
			!daemon->static_room_locations_match(
				"/gamelib/d/illusion_s1/fog_forest",
				"/gamelib/d/illusion_s1/mirror_lake.pike") &&
			!daemon->static_room_locations_match(
				"/gamelib/d/illusion_s1/fog_forest#2",
				"/gamelib/d/illusion_s1/fog_forest.pike"),
			"合法无后缀路径会误判到达失败，或动态/不同房间被错误视为同一owner");

		check("传统幻境静态入口与克隆房按同一队伍实例汇聚唯一worker",
			daemon->query_affinity_key(
				"/gamelib/d/fb_runtime/ingress.pike",
				"team_a/lingranzhiyan_h")==
				"fb_runtime:team_a/lingranzhiyan_h" &&
			daemon->query_affinity_key(
				"/gamelib/d/xinnian_fb/lingranzhiyan_h#9",
				"team_a/lingranzhiyan_h")==
				"fb_runtime:team_a/lingranzhiyan_h" &&
			daemon->query_affinity_key(
				"/gamelib/d/xinnian_fb/lingranzhiyan_h#10",
				"team_b/lingranzhiyan_h")!=
				"fb_runtime:team_a/lingranzhiyan_h" &&
			source_has("/gamelib/cmds/fb_entry.pike",
				"route_player_to_fb_ingress") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"is_fb_worker_ingress"),
			"跨worker幻境可能拒绝进入、拆散队伍或复制副本奖励");
		check("跨Worker到达不重复执行真实登录迁移且仅携带状态药快照",
			source_has("/gamelib/clone/user.pike",
				"int pending_worker_arrival = query_pending_worker_arrival()") &&
			source_has("/gamelib/clone/user.pike",
				"!pending_worker_arrival") &&
			source_has("/gamelib/clone/user.pike",
				"snapshot_worker_status_effects") &&
			source_has("/gamelib/clone/user.pike",
				"restore_worker_status_effects") &&
			source_has("/gamelib/clone/user.pike",
				"if(!worker_fenced_save)") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"finalize_worker_status_effect_handoff") &&
			!source_has("/gamelib/clone/user.pike",
				"snapshot[\"buff\"]") &&
			!source_has("/gamelib/clone/user.pike",
				"snapshot[\"team_guard\"]"),
			"地图切换会再次执行回收迁移、清掉装备，或复制战斗态Buff");
		check("新人物注册初始化不受已删除人物残留地图租约干扰",
			source_has("/gamelib/clone/user.pike",
				"void set_registration_bootstrap(int enabled)") &&
			source_has("/gamelib/clone/user.pike",
				"int worker_move_guard = registration_bootstrap ? 0 :") &&
			source_has("/gamelib/clone/user.pike",
				"registration_bootstrap=0;") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"me->set_registration_bootstrap(1);"),
			"新人物setup仍可能被旧租约重定向，或临时注册能力被保存");

		mapping restored_validation = daemon->validate_control_plane_snapshot(([
			"version":1,
			"affinity_assignments":([
				"wugongdong":(["worker_id":"w01","epoch":2,
					"weight":10,"assigned_at":time()]),
				"../bad":(["worker_id":"w02","epoch":1,"weight":1]),
			]),
			"player_leases":([
				"xd98orphan":(["worker_id":"w01","affinity":"wugongdong",
					"epoch":3,"state":"frozen","expires_at":time()+60,
					"updated_at":time()]),
			]),
			"handoffs":(["restore-mismatch":([
				"userid":"xd98missing","source_worker":"w01",
				"target_worker":"w02","source_epoch":1,"target_epoch":2,
				"target_affinity":"wugongdong","state":"committed",
				"created_at":time(),"expires_at":time()+60,
				"committed_at":time(),
			])]),"envelopes":([]),
			"escrow_transactions":([
				"restoretx1":(["from_user":"xd98from","to_user":"xd98to",
					"item":(["item_id":item_id,"digest":item_digest,"amount":1]),
					"state":"funded","created_at":time(),"expires_at":0]),
				"restoretx2":(["from_user":"xd98from","to_user":"xd98to2",
					"item":(["item_id":item_id,"digest":item_digest,"amount":1]),
					"state":"reserved","created_at":time(),
					"expires_at":time()+60]),
			]),"pk_sessions":([]),
		]));
		mapping restored_snapshot = restored_validation["snapshot"];
		check("控制面恢复逐字段校验并丢弃路径穿越与孤立冻结租约",
			restored_validation["ok"] &&
			(int)restored_validation["discarded"]==4 &&
			sizeof((mapping)restored_snapshot["affinity_assignments"])==1 &&
			sizeof((mapping)restored_snapshot["player_leases"])==0 &&
			sizeof((mapping)restored_snapshot["handoffs"])==0 &&
			sizeof((mapping)restored_snapshot["escrow_transactions"])==1,
			"损坏快照可能恢复伪造地图归属或永久冻结人物");
		mapping fb_restored_validation =
			daemon->validate_control_plane_snapshot(([
			"version":1,"affinity_assignments":([]),
			"player_leases":(["xd98fbrestore":([
				"worker_id":"w02",
				"affinity":"fb_runtime:team_a/lingranzhiyan_h",
				"epoch":2,"state":"active","expires_at":time()+60,
				"updated_at":time(),
				"arrival_room_path":"/gamelib/d/fb_runtime/ingress.pike",
				"arrival_epoch":2,
			])]),
			"handoffs":(["restore-fb-instance":([
				"userid":"xd98fbrestore","source_worker":"w01",
				"target_worker":"w02","source_epoch":1,"target_epoch":2,
				"target_affinity":"fb_runtime:team_a/lingranzhiyan_h",
				"target_room_path":"/gamelib/d/fb_runtime/ingress.pike",
				"state":"committed","created_at":time(),
				"expires_at":time()+60,"committed_at":time(),
			])]),"envelopes":([]),"escrow_transactions":([]),
			"pk_sessions":([]),
		]));
		mapping fb_restored_snapshot = fb_restored_validation["snapshot"];
		check("队伍副本实例到达凭证可在协调器重启后精确恢复",
			fb_restored_validation["ok"] &&
			(int)fb_restored_validation["discarded"]==0 &&
			sizeof((mapping)fb_restored_snapshot["player_leases"])==1 &&
			sizeof((mapping)fb_restored_snapshot["handoffs"])==1,
			"静态入口路径丢失服务端实例后缀会让重启中的副本玩家断线");
		check("控制面主文件损坏时仅从已验证备份恢复且串行持久化",
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"restored control plane from backup") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"control_persist_lock->lock()") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"!control_restored_from_backup") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"backup_temp_path = path+\".bak.tmp\"") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"backup_size==live_size") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"mv(backup_temp_path,backup_path)") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"control_persist_attempts") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"persist_average_ms") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"if(!control_persist_scheduled)"),
			"损坏主快照可能覆盖唯一好备份或并发写同一临时文件");
		check("控制面容量预算与恢复上限一致且耐久消息确认同步落盘",
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"MAP_WORKER_MAX_CONTROL_BYTES = 64*1024*1024") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"control plane exceeds durable size budget") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"MAP_WORKER_MAX_ESCROW_BYTES = 4096") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"original_message = copy_value(message)"),
			"运行时可能接受重启后无法恢复的快照，或提前确认未落盘消息");
		mapping incomplete_v2 = daemon->validate_control_plane_snapshot(([
			"version":2,"counts":(["affinity_assignments":1,
				"player_leases":0,"handoffs":0,"envelopes":0,
				"escrow_transactions":1,"pk_sessions":0]),
			"affinity_assignments":([]),"player_leases":([]),
			"handoffs":([]),"envelopes":([]),
			"escrow_transactions":([]),"pk_sessions":([]),
		]));
		check("新版控制快照字段或托管记录被截断时整代拒绝",
			!incomplete_v2["ok"] &&
			incomplete_v2["code"]=="incomplete_snapshot" &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"snapshot[\"counts\"]"),
			"可解析的残缺JSON可能静默清空人物租约或装备托管");

		for(int index=0;index<sizeof(worker_ids);index++){
			mapping registered = daemon->register_worker(worker_ids[index],
				"http://127.0.0.1:"+(19001+index),100,
				prefix+"incarnation"+index);
			registrations += ({registered});
		}
		check("只接受受限回环端点并给每次进程化身代数",
			registrations[0]["ok"] && registrations[1]["ok"] &&
			registrations[2]["ok"] &&
			(int)registrations[0]["generation"]==1 &&
			!daemon->register_worker(prefix+"bad",
				"http://192.168.1.205:19009",100,prefix+"badinc")["ok"],
			"worker 注册未限制端点、数量或 generation");

		mapping catalog = daemon->assign_catalog(1);
		status = daemon->query_status();
		check("控制面状态按迁移阶段计数并暴露最老prepared年龄",
			mappingp(status["handoff_states"]) &&
			(int)status["oldest_prepared_handoff_age"]>=0,
			"总handoff数无法区分正常历史记录与卡住的prepared迁移");
		mapping(string:int) counts = ([]);
		mapping(string:int) weights = ([]);
		multiset(string) s1_workers = (<>);
		multiset(string) s1_hunt_workers = (<>);
		int s1_group_count;
		int largest_affinity_weight;
		int heat_shape_valid = 1;
		string known_static_affinity = "";
		foreach((array)status["placements"],mapping one){
			string owner = (string)one["worker_id"];
			if(has_prefix((string)one["affinity"],"illusion_s1:")){
				s1_group_count++;
				s1_workers[owner] = 1;
			}
			if(has_prefix((string)one["affinity"],
			   "illusion_s1:hunt_"))
				s1_hunt_workers[owner] = 1;
			if(has_value(worker_ids,owner)){
				counts[owner]++;
				weights[owner] += (int)one["weight"];
				if(!intp(one["heat_score"]))
					heat_shape_valid = 0;
				largest_affinity_weight = max(largest_affinity_weight,
					(int)one["weight"]);
				if(known_static_affinity=="" && (int)one["static_weight"]>0)
					known_static_affinity = (string)one["affinity"];
			}
		}
		valid = heat_shape_valid && catalog["ok"] &&
			(int)catalog["catalog_size"]>=60;
		foreach(worker_ids,string worker_id)
			if(counts[worker_id]<1 || weights[worker_id]<1)
				valid = 0;
		check("约2693个房间按目录权重分布到3个worker",
			valid,"冷启动目录未覆盖所有worker或地图目录缺失");
		check("S1七个剧情与猎场亲和组在冷启动时实际使用多个worker",
			s1_group_count==7 && sizeof(s1_workers)>=3,
			sprintf("groups=%d workers=%O",s1_group_count,
				indices(s1_workers)));
		check("S1三组公共猎场在三节点冷启动时强制互不共置",
			sizeof(s1_hunt_workers)==3,
			sprintf("hunt_workers=%O",indices(s1_hunt_workers)));
		array(int) worker_weights = values(weights);
		int lightest_worker_weight = sizeof(worker_weights) ?
			worker_weights[0] : 0;
		int heaviest_worker_weight = lightest_worker_weight;
		foreach(worker_weights,int worker_weight){
			lightest_worker_weight = min(lightest_worker_weight,worker_weight);
			heaviest_worker_weight = max(heaviest_worker_weight,worker_weight);
		}
		check("冷启动按最大有效权重优先分箱且各节点差值受单图上限约束",
			sizeof(worker_weights)==3 &&
			heaviest_worker_weight-lightest_worker_weight<=
				largest_affinity_weight &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"choose_catalog_worker_unlocked") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"Largest effective maps first"),
			"热门或大型地图仍可能集中到同一worker");
		mapping valid_heat = daemon->validate_affinity_heat_snapshot(([
			"version":1,"generation":2,"saved_at":time(),
			"observed_at":time(),"scores":([known_static_affinity:1200]),
		]));
		mapping invalid_heat = daemon->validate_affinity_heat_snapshot(([
			"version":1,"generation":2,"saved_at":time(),
			"observed_at":time(),"scores":(["../player/xd98secret":1200]),
		]));
		check("地图热度快照只保存已知地图聚合值并严格限制格式与容量",
			known_static_affinity!="" && valid_heat["ok"] &&
			(int)valid_heat["scores"][known_static_affinity]==1200 &&
			!invalid_heat["ok"] &&
			daemon->calculate_affinity_effective_weight(10,1000)==260 &&
			daemon->calculate_affinity_effective_weight(0,-1)==1 &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"MAP_WORKER_MAX_HEAT_BYTES = 1024*1024") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"backup_temp_path = path+\".bak.tmp\"") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"seed_affinity_heat_from_restored_leases"),
			"热度文件可能泄漏角色、接受越界内容或无法安全恢复");

		placement = daemon->assign_affinity(source_affinity,3,1);
		source_worker = (string)placement["worker_id"];
		mapping sticky = daemon->assign_affinity(source_affinity,999,0);
		check("活跃地图使用粘性归属且普通请求不触发搬迁",
			placement["ok"] && sticky["ok"] && sticky["sticky"] &&
			sticky["worker_id"]==source_worker &&
			sticky["epoch"]==placement["epoch"],
			"权重变化造成无授权地图迁移");
		check("新地图owner和人物epoch必须同步落盘后才对网关可见",
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"New routing authority is usable only after") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"A lease is the equipment single-owner fence") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"Inventory recovery is also an ownership grant") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"control_persist_failed"),
			"协调器崩溃可能遗忘已经允许加载人物装备的owner/epoch");

		mapping missing_route = daemon->query_player_route(userid);
		lease = daemon->acquire_player_lease(userid,source_worker,
			source_affinity,0);
		check("人物租约包含worker、affinity和单调epoch",
			missing_route["code"]=="lease_missing" && lease["ok"] &&
			lease["worker_id"]==source_worker &&
			lease["affinity"]==source_affinity && (int)lease["epoch"]>=1,
			"首登被误判为过期恢复，或人物可能同时被多个worker持有");
		string mixed_case_user="xd98Case"+prefix;
		string lower_case_user=lower_case(mixed_case_user);
		mapping mixed_case_lease=daemon->acquire_player_lease(
			mixed_case_user,source_worker,source_affinity,0);
		mapping lower_case_lease=daemon->acquire_player_lease(
			lower_case_user,source_worker,source_affinity,0);
		check("多Worker租约保留账号精确大小写且不串号",
			mixed_case_lease["ok"] && lower_case_lease["ok"] &&
			daemon->query_player_route(mixed_case_user)["userid"]==
				mixed_case_user &&
			daemon->query_player_route(lower_case_user)["userid"]==
				lower_case_user && mixed_case_user!=lower_case_user,
			"大小写账号被协调器折叠为同一人物租约");
		mapping batch_bad = daemon->renew_player_leases_batch(source_worker,
			(int)registrations[member_array(source_worker,worker_ids)]["generation"],
			({(["userid":userid,"epoch":lease["epoch"],
				"affinity":target_affinity])}));
		mapping batch_ok = daemon->renew_player_leases_batch(source_worker,
			(int)registrations[member_array(source_worker,worker_ids)]["generation"],
			({(["userid":userid,"epoch":lease["epoch"],
				"affinity":source_affinity])}));
		check("后台挂机人物由worker心跳批量续租且地图不匹配时失败关闭",
			batch_bad["code"]=="stale_lease" && batch_ok["ok"] &&
			(int)batch_ok["renewed"]==1 &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"handle_map_worker_local_live_leases") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"local_user_request_running(userid)") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_renew_live_player_leases(worker_id,generation)") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_live_player_leases_renew_after_generation_ack_before_control"),
			"后台挂机无浏览器请求时租约可能过期，或错误owner被静默续租");

		string churn_user = userid+"churn";
		mapping churn_lease = daemon->acquire_player_lease(churn_user,
			source_worker,source_affinity,0);
		mapping churn_batch = daemon->renew_player_leases_batch(source_worker,
			(int)registrations[member_array(source_worker,worker_ids)]["generation"],
			({(["userid":userid,"epoch":(int)lease["epoch"],
				"affinity":source_affinity]),
			  (["userid":churn_user,"epoch":(int)churn_lease["epoch"]+1,
				"affinity":source_affinity])}));
		check("单个租约正常迁移不连坐整批续租且全stale仍失败关闭",
			churn_batch["ok"] && (int)churn_batch["renewed"]==1 &&
			(int)churn_batch["count"]==1 && (int)churn_batch["stale"]==1,
			"并发迁移/下线让健康worker整批续租被拒并遭误隔离");

		int source_index = member_array(source_worker,worker_ids);
		string premature_worker = worker_ids[(source_index+1)%sizeof(worker_ids)];
		mapping rebound = daemon->rebind_player_lease(userid,source_worker,
			(int)lease["epoch"],source_affinity);
		mapping bad_rebind = daemon->rebind_player_lease(userid,
			premature_worker,(int)lease["epoch"],source_affinity);
		check("同worker移动只在人物epoch与地图owner一致时更新租约",
			rebound["ok"] && rebound["affinity"]==source_affinity &&
			bad_rebind["code"]=="affinity_owner_mismatch" &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"The room move already happened") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_same_worker_completed_move_rebinds_lease_affinity") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_full_recovery_rebinds_same_worker_affinity_mismatch") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_unreconstructable_dynamic_room_never_crosses_workers"),
			"同进程地图切换可能留下旧租约，或把动态实例复制到另一进程");
		daemon->set_worker_draining(source_worker,1);
		mapping premature_takeover = daemon->acquire_player_lease(userid,
			premature_worker,source_affinity,0);
		daemon->set_worker_draining(source_worker,0);
		check("节点暂时不可用也不能抢占尚未过期的人物租约",
			premature_takeover["code"]=="lease_owned" &&
			premature_takeover["owner"]==source_worker &&
			(int)premature_takeover["epoch"]==(int)lease["epoch"],
			"网络分区时第二个worker可能提前加载同一人物和装备");
			check("租约过期也不作为跨worker抢占与删除防重墓碑的证明",
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"an ordinary acquire may only reopen the same logical worker") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"Expired player leases are durable fencing tombstones") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_expired_lease_reopens_only_on_its_previous_worker"),
				"超时长命令可能和新worker同时写人物档案或装备");
			mapping gc_begin = daemon->begin_lease_reconciliation(prefix+"gc");
			mapping gc_add = daemon->add_lease_reconciliation_users(prefix+"gc",
				({userid,target_user}));
			mapping gc_commit = daemon->commit_lease_reconciliation(prefix+"gc");
			check("过期租约仅在停流后的全worker盘点中分块安全回收",
				gc_begin["ok"] && gc_add["ok"] && gc_commit["ok"] &&
				source_has("/gamelib/single/daemons/map_workerd.pike",
					"lease_reconciliation_live_users") &&
				source_has("/gamelib/single/daemons/map_workerd.pike",
					"query_local_player_userids") &&
				source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
					"map_worker_local_players") &&
				source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
					"Epoch entries with no living object") &&
				source_has("/gamelib/single/daemons/map_workerd.pike",
					"normalize_room_location((string)lease[\"arrival_room_path\"])") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"pike_gateway_prune_reconciled_tombstones(live_users)") &&
				source_has("/test_unit/test_pike_gateway.pike",
					"test_reconciled_lease_gc_uploads_bounded_inventory_chunks"),
				"长期运行可能耗尽租约/会话放置容量，或误删仍持有装备的旧owner");
		check("长时间运行会定期停流盘点后回收首登session和过期租约",
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"XIAND_MAP_WORKER_LEASE_GC_SECONDS") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_run_lease_gc()") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"if(!recovery_err)\n\t\tpike_gateway_resume_routing()") &&
			source_has("/.env.example",
				"XIAND_MAP_WORKER_LEASE_GC_SECONDS=3600") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_failed_periodic_lease_gc_keeps_routing_paused"),
			"运行期间首登session与防重墓碑会持续累积直到容量耗尽");

			daemon->heartbeat_worker(source_worker,
			(int)registrations[source_index]["generation"],([
				"active_players":1000,"active_rooms":1000,
				"pending_commands":100000,"heartbeat_ms":600000,
			]));
		mapping target_placement = daemon->assign_affinity(
			target_affinity,1,1);
		target_worker = (string)target_placement["worker_id"];
		check("实时负载会把新地图避开严重拥塞worker",
			target_placement["ok"] && target_worker!=source_worker,
			"新地图仍被放到拥塞worker");

		string fb_user = userid+"fb";
		string fb_affinity = "fb_runtime:"+prefix+"/instance";
		string fb_room = "/gamelib/d/fb_runtime/ingress.pike";
		string fb_request = request_id+"fb";
		mapping fb_placement = daemon->assign_affinity(fb_affinity,1,1);
		mapping fb_lease = daemon->acquire_player_lease(fb_user,
			source_worker,source_affinity,0);
		mapping fb_handoff = daemon->begin_handoff(fb_user,source_worker,
			(int)fb_lease["epoch"],fb_affinity,fb_room,fb_request);
		mapping bad_fb_handoff = daemon->begin_handoff(fb_user,source_worker,
			(int)fb_lease["epoch"],"fb_runtime:../forged",fb_room,
			fb_request+"bad");
		string fb_target = (string)fb_placement["worker_id"];
		mapping fb_commit = daemon->commit_handoff(fb_request,fb_target);
		mapping fb_reopen = daemon->acquire_player_lease(fb_user,fb_target,
			fb_affinity,(int)fb_commit["target_epoch"]);
		mapping fb_ack = daemon->acknowledge_player_arrival(fb_user,fb_target,
			(int)fb_commit["target_epoch"],fb_affinity);
		check("合法队伍副本入口可完成跨Worker迁移且伪造实例仍被拒绝",
			fb_placement["ok"] &&
			fb_placement["worker_id"]!=source_worker && fb_lease["ok"] &&
			fb_handoff["ok"] && fb_handoff["state"]=="prepared" &&
			fb_handoff["target_affinity"]==fb_affinity &&
			bad_fb_handoff["code"]=="invalid_handoff" && fb_commit["ok"] &&
			fb_reopen["ok"] && fb_reopen["arrival_room_path"]==fb_room &&
			fb_ack["ok"],
			"实例affinity被误拒会让飞副本断线，或伪造实例可绕过入口");

		string drift_user = userid+"drift";
		string drift_affinity = "drift"+prefix;
		string drift_room = "/gamelib/d/"+drift_affinity+"/room";
		string drift_request = request_id+"drift";
		mapping drift_placement = daemon->assign_affinity(
			drift_affinity,1,1);
		string drift_target = (string)drift_placement["worker_id"];
		mapping drift_lease = daemon->acquire_player_lease(drift_user,
			source_worker,source_affinity,0);
		mapping drift_prepare = daemon->begin_handoff(drift_user,source_worker,
			(int)drift_lease["epoch"],drift_affinity,drift_room,drift_request);
		daemon->set_worker_draining(drift_target,1);
		mapping moved_placement = daemon->assign_affinity(
			drift_affinity,1,1);
		daemon->set_worker_draining(drift_target,0);
		mapping moved_commit = daemon->commit_handoff(
			drift_request,drift_target);
		mapping drift_abort = daemon->abort_handoff(
			drift_request,source_worker);
		check("迁移prepare期间target地图改归属时禁止提交旧worker",
			drift_placement["ok"] && drift_target!=source_worker &&
			drift_lease["ok"] && drift_prepare["ok"] &&
			moved_placement["ok"] &&
			moved_placement["worker_id"]!=drift_target &&
			moved_commit["code"]=="target_affinity_moved" &&
			drift_abort["ok"] &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"active_affinities[(string)handoff[\"target_affinity\"]]"),
			"重均衡竞态可能把人物提交到已不拥有目标地图的worker");

		handoff = daemon->begin_handoff(userid,source_worker,
			(int)lease["epoch"],target_affinity,target_room_path,request_id);
		mapping frozen = daemon->query_player_route(userid);
		mapping frozen_reacquire = daemon->acquire_player_lease(userid,
			source_worker,source_affinity,(int)lease["epoch"]);
		mapping handoff_collision = daemon->begin_handoff(userid,source_worker,
			(int)lease["epoch"],target_affinity,target_room_path+"other",
			request_id);
		mapping wrong_commit = daemon->commit_handoff(request_id,source_worker);
		check("迁移prepare冻结源租约，冻结期不能重获且幂等ID绑定参数",
			handoff["ok"] && handoff["state"]=="prepared" &&
			frozen["state"]=="frozen" &&
			frozen["handoff_request_id"]==request_id &&
			frozen_reacquire["code"]=="lease_frozen" &&
			handoff_collision["code"]=="idempotency_conflict" &&
			!wrong_commit["ok"],
			"冻结租约被重开、迁移ID碰撞或目标worker可被伪造");

		daemon->set_worker_draining(target_worker,1);
		mapping unavailable_commit = daemon->commit_handoff(
			request_id,target_worker);
		daemon->set_worker_draining(target_worker,0);
		committed = daemon->commit_handoff(request_id,target_worker);
		mapping route_after = daemon->query_player_route(userid);
		mapping committed_proof = daemon->query_committed_handoff_proof(
			userid,source_worker,(int)lease["epoch"],target_worker,
			(int)lease["epoch"]+1);
		mapping wrong_committed_proof = daemon->query_committed_handoff_proof(
			userid,source_worker,(int)lease["epoch"]-1,target_worker,
			(int)lease["epoch"]+1);
		mapping replayed = daemon->commit_handoff(request_id,target_worker);
		mapping wrong_arrival_ack = daemon->acknowledge_player_arrival(userid,
			target_worker,(int)lease["epoch"]+1,source_affinity);
		mapping arrival_ack = daemon->acknowledge_player_arrival(userid,
			target_worker,(int)lease["epoch"]+1,target_affinity);
		mapping route_arrived = daemon->query_player_route(userid);
		check("迁移commit原子切换worker和epoch且重试幂等",
			unavailable_commit["code"]=="target_unavailable" &&
			committed["ok"] && route_after["worker_id"]==target_worker &&
			(int)route_after["epoch"]==(int)lease["epoch"]+1 &&
			route_after["state"]=="active" &&
			route_after["arrival_room_path"]==target_room_path &&
			committed_proof["ok"] &&
			committed_proof["source_worker"]==source_worker &&
			(int)committed_proof["source_epoch"]==(int)lease["epoch"] &&
			committed_proof["target_worker"]==target_worker &&
			(int)committed_proof["target_epoch"]==(int)lease["epoch"]+1 &&
			(int)committed_proof["committed_at"]>0 &&
			!wrong_committed_proof["ok"] &&
			wrong_arrival_ack["code"]=="arrival_fence_failed" &&
			arrival_ack["ok"] && !route_arrived["arrival_room_path"] &&
			replayed["ok"] &&
			replayed["replayed"],
			"迁移可能出现双活、旧epoch复用或重试失败");

		int handoffs_before = (int)daemon->query_status()["handoffs"];
		int aged_records = daemon->test_backdate_terminal_handoffs(660);
		daemon->test_run_cleanup_expired_state();
		int handoffs_after = (int)daemon->query_status()["handoffs"];
		mapping aged_proof = daemon->query_committed_handoff_proof(userid,
			source_worker,(int)lease["epoch"],target_worker,
			(int)lease["epoch"]+1);
		check("终态迁移记录按短保留期回收避免handoff表饱和",
			aged_records>0 && handoffs_after<handoffs_before &&
			!aged_proof["ok"] &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"MAP_WORKER_HANDOFF_RETENTION_TTL"),
			"一天保留期让正常跨图流量填满4096上限并永久拒绝后续迁移");

		string retry_user = userid+"retry";
		string retry_request = request_id+"retry";
		mapping retry_lease = daemon->acquire_player_lease(retry_user,
			source_worker,source_affinity,0);
		mapping retry_prepare = daemon->begin_handoff(retry_user,source_worker,
			(int)retry_lease["epoch"],target_affinity,target_room_path,
			retry_request);
		mapping retry_abort = daemon->abort_handoff(retry_request,source_worker);
		mapping retry_reprepare = daemon->begin_handoff(retry_user,source_worker,
			(int)retry_lease["epoch"],target_affinity,target_room_path,
			retry_request);
		mapping retry_route = daemon->query_player_route(retry_user);
		check("已终止的同一迁移幂等键仅在精确源租约复核后可安全重备",
			retry_lease["ok"] && retry_prepare["ok"] && retry_abort["ok"] &&
			retry_reprepare["ok"] && retry_reprepare["state"]=="prepared" &&
			retry_route["state"]=="frozen" &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_handoff_target_or_state_drift_is_rejected_before_source_release"),
			"过期/改道prepare可能在释放源人物后才被发现，造成移动丢失或重复加载");
		daemon->abort_handoff(retry_request,source_worker);

		mapping message_payload = (["text":"test","source_name":"测试者"]);
		mapping message = daemon->publish_envelope(message_id,"tell",userid,
			target_user,message_payload);
		mapping message_replay = daemon->publish_envelope(message_id,"tell",userid,
			target_user,message_payload);
		mapping message_collision = daemon->publish_envelope(message_id,"tell",
			userid,target_user,(["text":"different"]));
		array polled = daemon->poll_envelopes(target_user,20);
		array concurrently_polled = daemon->poll_envelopes(target_user,20);
		mapping acked = daemon->acknowledge_envelope(message_id,target_user,
			(int)polled[0]["delivery_epoch"]);
		mapping ack_replay = daemon->acknowledge_envelope(message_id,target_user,
			(int)polled[0]["delivery_epoch"]);
		check("跨worker消息绑定幂等参数、领取租约、delivery epoch和ACK",
			message["ok"] && message_replay["replayed"] &&
			message_collision["code"]=="idempotency_conflict" &&
			sizeof(polled)==1 && polled[0]["message_id"]==message_id &&
			sizeof(concurrently_polled)==0 && acked["ok"] &&
			ack_replay["replayed"] &&
			sizeof(daemon->poll_envelopes(target_user,20))==0,
			"消息可能ID碰撞、并发重复领取、旧epoch ACK或串收件人");
		check("公共频道消息使用同一有界社会事件通道同步所有Worker",
			source_has("/gamelib/cmds/chatroom_chat.pike",
				"RACECHATD->publish_chat_msg") &&
			source_has("/gamelib/single/daemons/racechatd.pike",
				"\"channel_chat\"") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"if(kind==\"channel_chat\")") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"map_worker_apply_channel_chat") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"\"world_broadcast\",\"channel_chat\""),
			"普通频道仍可能按Worker分裂或接受未知社会事件类型");

		mapping escrow = daemon->create_escrow(transaction_id,userid,target_user,
			(["item_id":item_id,"amount":1,"digest":item_digest]));
		mapping escrow_collision = daemon->create_escrow(transaction_id,userid,
			target_user+"x",(["item_id":item_id,"amount":1,
			"digest":item_digest]));
		mapping duplicate_item = daemon->create_escrow(transaction_id+"other",
			userid,target_user,(["item_id":item_id,"amount":1,
			"digest":item_digest]));
		mapping wrong_digest = daemon->advance_escrow(transaction_id,userid,
			"reserved","funded",
			"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc");
		mapping funded = daemon->advance_escrow(transaction_id,userid,
			"reserved","funded",item_digest);
		mapping unsafe_cancel = daemon->advance_escrow(transaction_id,userid,
			"funded","cancelled",item_digest);
		mapping forged = daemon->advance_escrow(transaction_id,userid,
			"funded","delivered",item_digest);
		mapping delivered = daemon->advance_escrow(transaction_id,target_user,
			"funded","delivered",item_digest);
		mapping delivery_replay = daemon->advance_escrow(transaction_id,target_user,
			"funded","delivered",item_digest);
		mapping forged_replay = daemon->advance_escrow(transaction_id,userid,
			"funded","delivered",item_digest);
		check("装备托管绑定事务内容且禁止出资后取消、越权及重复领取",
			escrow["ok"] &&
			escrow_collision["code"]=="idempotency_conflict" &&
			duplicate_item["code"]=="item_already_escrowed" &&
			wrong_digest["code"]=="item_digest_mismatch" &&
			funded["ok"] && unsafe_cancel["code"]=="invalid_state" &&
			!forged["ok"] &&
			delivered["ok"] && delivery_replay["replayed"],
			"装备可能事务碰撞、资金态丢失、越权领取或重复领取");
		check("装备托管的创建与每次状态跃迁均同步落盘后才确认",
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"An equipment reservation is not acknowledged until durable") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"escrow_transactions[transaction_id] = original_tx"),
			"协调器崩溃可能遗忘已扣除或已交付装备的事务状态");
		check("已完成装备事务的幂等重放仍校验领取者",
			!forged_replay["ok"] && forged_replay["code"]==
				"escrow_fence_failed",
			"非接收者可借幂等重放伪造领取成功");
		check("拍卖命令与超时结算在所有worker间共用唯一串行锁",
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_auction_lock = Thread.Mutex()") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_auction_command(game_command)") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"local_auction_tick") &&
			source_has("/gamelib/single/daemons/auctiond.pike",
				"run_map_worker_scheduled_task") &&
			source_has("/gamelib/single/daemons/auctiond.pike",
				"MAP_WORKERD->local_control_lease_valid()") &&
			source_has("/gamelib/single/daemons/auctiond.pike",
				"if(!MAP_WORKERD->distributed_mode_enabled())") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_only_auction_commands_use_cluster_global_command_lock"),
			"多进程可能同时结算同一拍卖并重复退款或发放装备");

		mapping pk = daemon->create_pk_session(prefix+"pk",userid,target_user);
		mapping pk_replay = daemon->create_pk_session(prefix+"pk",userid,target_user);
		mapping pk_collision = daemon->create_pk_session(prefix+"pk",userid,
			target_user+"other");
		check("跨地图PK聚合控制面原语具备幂等与碰撞栅栏",
			pk["ok"] && pk["state"]=="gathering" &&
			pk["worker_id"]!="" && pk["worker_id"]==pk_replay["worker_id"] &&
			has_prefix((string)pk["affinity"],"pk:") &&
			pk_collision["code"]=="idempotency_conflict",
			"PK仍可能跨进程直接修改双方战斗对象");

		mapping denied_config = daemon->admin_set_cluster_config(
			"xd98ordinary",1,3,100);
		check("worker开关、扩容、排空和重均衡只向管理员开放",
			!denied_config["ok"] &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"cluster_config_lock->lock()") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"path+\".\"+local_worker_id+\".tmp\"") &&
			source_has("/scripts/map_worker_cluster.sh",
				"XIAND_MAP_WORKER_RUNTIME_COUNT") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"query_runtime_worker_count()") &&
			source_has("/gamelib/cmds/mgr_map_workers.pike",
				"MANAGERD->checkpower") &&
			source_has("/gamelib/cmds/mgr_map_workers.pike",
				"rebalance confirm") &&
			source_has("/gamelib/cmds/mgr_map_workers.pike",
				"search(arg,\"active\")!=-1") &&
			source_has("/gamelib/cmds/mgr_map_workers.pike",
				"运行期排空/重均衡只能由持有内部令牌") &&
			source_has("/gamelib/cmds/mgr_map_workers.pike",
				"query_node_role()!=\"gateway\"") &&
			source_has("/gamelib/cmds/mgr_map_workers.pike",
				"当前最高负载地图域") &&
			source_has("/gamelib/cmds/mgr_map_workers.pike",
				"backend_lag_ms") &&
			source_has("/gamelib/cmds/mgr_map_workers.pike",
				"persist_max_ms") &&
			source_has("/gamelib/d/manager_room","mgr_map_workers") &&
			source_has("/gamelib/cmds/game_deal.pike","mgr_map_workers"),
			"管理面可能越权或缺少安全确认入口");

		mapping config = daemon->query_cluster_config();
		mapping example_config = Standards.JSON.decode(Stdio.read_file(ROOT+
			"/deploy/map_workers/config.example.json"));
		check("试运行默认关闭、默认3个worker且登录/逻辑区源码未改",
			!(int)example_config["enabled"] &&
			(int)example_config["schema_version"]==2 &&
			(string)example_config["traffic_mode"]=="shadow" &&
			(int)example_config["worker_count"]==3 &&
			(int)config["worker_count"]>=1 && (int)config["worker_count"]<=16 &&
				(string)config["placement"]=="load_aware_rendezvous" &&
				has_value(({"shadow","active"}),
					(string)config["traffic_mode"]) &&
			!source_has("/gamelib/single/daemons/map_workerd.pike",
				"login_allowed(") &&
			!source_has("/gamelib/single/daemons/map_workerd.pike",
				"set_account_owner"),
			"试运行可能自动开启或侵入账号/逻辑区登录");

		check("编排器仅绑定回环内部端口且保留单进程回退",
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"http://127.0.0.1:") &&
			source_has("/gamelib/single/daemons/_http_api_mod/config.pike",
				"return \"127.0.0.1\"") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"http_listen_port, http_listen_host") &&
			source_has("/scripts/map_worker_cluster.sh",
				"XIAND_HTTP_HOST='127.0.0.1'") &&
			!source_has("/docker/docker-compose.yml","18880:") &&
			!source_has("/docker/docker-compose.yml","18881:") &&
			!source_has("/docker/docker-compose.yml","14801:") &&
			source_has("/scripts/map_worker_cluster.sh",
				"stop standalone/old cluster explicitly") &&
			source_has("/scripts/map_worker_cluster.sh",
				"normal restart script remains the rollback path") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"method==\"HEAD\" ? \"\"") &&
			source_has("/gamelib/single/daemons/testunitd.pike",
				"getenv(\"XIAND_RUN_TESTUNIT\")!=\"1\"") &&
			source_has("/gamelib/single/daemons/testunitd.pike",
				"SKIP disabled node role"),
			"内部RPC可能外露、抢占现网端口或多节点重复跑TestUnit");

		check("TestUnit清档仅命中保留测试命名空间",
			((object)(ROOT+"/gamelib/single/daemons/testunitd.pike"))->
				query_testunit_archive_filename_for_test(
					"__testunit_demo__.o") &&
			((object)(ROOT+"/gamelib/single/daemons/testunitd.pike"))->
				query_testunit_archive_filename_for_test(
					"xd01testunitdemo.o.bak.tmp") &&
			((object)(ROOT+"/gamelib/single/daemons/testunitd.pike"))->
				query_testunit_archive_filename_for_test(
					"xd01testunitdemo.o.recover.tmp") &&
			!((object)(ROOT+"/gamelib/single/daemons/testunitd.pike"))->
				query_testunit_archive_filename_for_test(
					"xd01player_testunit_demo.o") &&
			!((object)(ROOT+"/gamelib/single/daemons/testunitd.pike"))->
				query_testunit_archive_filename_for_test(
					"xd01testunitdemo.json"),
			"普通玩家名或非人物档案仍可能被测试清理误删");

		check("worker只预启动归属安全daemon，shadow不接流量且active需隔离机确认",
			source_has("/lowlib/system/master.pike",
				"Map-worker node skipping eager daemon") &&
			source_has("/lowlib/system/master.pike",
				"int map_worker_node = node_role==\"gateway\" ||") &&
			source_has("/lowlib/system/master.pike",
				"A map worker must not eagerly start another copy") &&
			source_has("/lowlib/system/master.pike","roomLeveld.pike") &&
			source_has("/lowlib/system/master.pike","kuangd.pike") &&
			source_has("/lowlib/system/master.pike","caoyaod.pike") &&
			source_has("/lowlib/system/master.pike","timed_eventd.pike") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"local_affinity_assignments_ready") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"controller ready; mode=%s workers=%d") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"if(!pike_gateway_shadow &&") &&
				source_has("/test_unit/test_pike_gateway.pike",
					"test_shadow_controller_never_runs_auction_settlement") &&
			source_has("/scripts/map_worker_cluster.sh",
				"XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"XIAND_MAP_WORKER_ACTIVE_TRIAL_ACK") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_direct_active_gateway_requires_isolated_trial_acknowledgement") &&
			source_has("/scripts/map_worker_cluster.sh",
				"isolated-test-server-only") &&
			source_has("/gamelib/cmds/mgr_map_workers.pike",
				"shadow（不接玩家流量）"),
			"后台开关可能直接切走生产流量或重复运行全局定时任务");

		check("编排启动失败会清理本次节点且缩容后仍按已启动拓扑安全停止",
			source_has("/scripts/map_worker_cluster.sh",
				"cleanup_partial_start") &&
			source_has("/scripts/map_worker_cluster.sh",
				"STARTED_SESSIONS") &&
			source_has("/scripts/map_worker_cluster.sh",
				"topology.json") &&
			source_has("/scripts/map_worker_cluster.sh",
				"topology_value worker_count") &&
			source_has("/scripts/map_worker_cluster.sh",
				"nc is required for safe shutdown") &&
			source_has("/scripts/map_worker_cluster.sh",
				"terminate_runtime_process") &&
			source_has("/scripts/map_worker_cluster.sh",
				"refusing to force-kill") &&
			source_has("/scripts/map_worker_cluster.sh",
				"$run_dir/$worker_id.pid"),
			"半启动节点可能残留、缩容后旧worker可能未保存就被遗忘");
		check("正常停机对瞬时pending请求有界重试且不放过不确定执行",
			source_has("/scripts/map_worker_cluster.sh",
				"deadline = time.monotonic() + (30 if failed_workers else 120)") &&
			source_has("/scripts/map_worker_cluster.sh",
				"gateway_not_quiescent\", \"gateway_recovery_busy") &&
			source_has("/scripts/map_worker_cluster.sh","attempt < 4") &&
			source_has("/scripts/map_worker_cluster.sh",
				"result.get(\"routing_resumed\", 1) != 0") &&
			source_has("/scripts/map_worker_cluster.sh",
				"coordinator refused the safe shutdown barrier") &&
			source_has("/scripts/map_worker_cluster.sh",
				"${BASH_SOURCE[0]}\" == \"$0") &&
			source_has("/tools/map_workers/test_quiesce_retry.sh",
				"\"pending_requests\": 3") &&
			source_has("/tools/map_workers/test_quiesce_retry.sh",
				"\"uncertain_requests\": 1") &&
			source_has("/tools/map_workers/test_quiesce_retry.sh",
				"expected HTTP conflict leaked a Python traceback") &&
			source_has("/restart-docker.sh",
				"stop_old_map_worker_cluster.sh") &&
			source_has("/scripts/stop_old_map_worker_cluster.sh",
				"for attempt in 1 2") &&
			source_has("/scripts/stop_old_map_worker_cluster.sh",
				"gateway_not_quiescent") &&
			source_has("/scripts/stop_old_map_worker_cluster.sh",
				"Traceback") &&
			source_has("/scripts/stop_old_map_worker_cluster.sh",
				"exit \"$stop_status\"") &&
			source_has("/tools/map_workers/test_old_container_stop_retry.sh",
				"unsafe old stop must remain fail-closed"),
			"第一次409仍会中断部署、无限重试或绕过不确定请求栅栏");
		check("本地与Docker重启可显式选择1到16个worker且默认仍为3",
			source_has("/scripts/map_worker_cluster.sh","restart|recover-gateway") &&
			source_has("/scripts/map_worker_cluster.sh","--workers N") &&
			source_has("/scripts/map_worker_cluster.sh","update_worker_count") &&
			source_has("/restart-docker.sh","CLI_WORKER_COUNT") &&
			source_has("/restart-docker.sh","XIAND_MAP_WORKER_COUNT_OVERRIDE") &&
			source_has("/restart-all-docker.sh","\"$@\"") &&
			source_has("/scripts/bootstrap_map_worker_runtime.sh",
				"XIAND_MAP_WORKER_COUNT_OVERRIDE") &&
			source_has("/restart-local-workers.sh",
				"restart_map_workers_with_testunit.sh") &&
			source_has("/scripts/restart_map_workers_with_testunit.sh",
				"XIAND_STOP_AFTER_TESTUNIT=1") &&
			source_has("/scripts/restart_map_workers_with_testunit.sh",
				"XIAND_MAP_WORKER_FAILOVER_SHUTDOWN=1") &&
			source_has("/docker/docker-compose.yml",
				"XIAND_MAP_WORKER_COUNT=${XIAND_MAP_WORKER_COUNT:-3}"),
			"一键重启可能忽略worker数量、覆盖其他后台配置或偏离默认3个");
		check("生产一键脚本会校验并同步Git worker配置到宿主持久卷",
			source_has("/restart-all-docker.sh",
				"XIAND_MAP_WORKER_DEPLOY_CONFIG") &&
			source_has("/restart-docker.sh",
				"sync_map_worker_deploy_config.sh") &&
			source_has("/restart-docker.sh",
				"preflight_map_worker_deploy_config") &&
			source_has("/restart-docker.sh",
				"Git worker配置预检失败，旧容器保持运行") &&
			source_has("/scripts/sync_map_worker_deploy_config.sh",
				"deploy config keys do not match schema v2") &&
			source_has("/scripts/sync_map_worker_deploy_config.sh",
				"deploy config exceeds 64 KiB") &&
			source_has("/scripts/sync_map_worker_deploy_config.sh",
				"mv -f \"$temporary\" \"$TARGET_CONFIG\"") &&
			source_has("/restart-docker.sh",
				"宿主worker配置路径不安全，旧容器保持运行") &&
			source_has("/deploy/map_workers/config.json",
				"\"traffic_mode\": \"active\"") &&
			source_has("/deploy/map_workers/config.json",
				"\"worker_count\": 5"),
			"生产配置可能未同步、校验失败后覆盖有效配置或未启用5个worker");
		string restart_source = Stdio.read_file(ROOT+"/restart-docker.sh");
		int preflight_call = restart_source ? search(restart_source,
			"\n    preflight_map_worker_deploy_config\n") : -1;
		int stop_call = restart_source ? search(restart_source,
			"\n    stop_existing_container_safely\n") : -1;
		check("生产worker配置在停止旧容器之前完成预检",
			preflight_call!=-1 && stop_call!=-1 && preflight_call<stop_call,
			"无效Git配置可能先停止仍可服务的旧容器");
		check("显式环境变量优先于.env，避免编排命令误操作其他区服",
			source_has("/scripts/map_worker_cluster.sh",
				"inherited_game_area") &&
			source_has("/scripts/map_worker_cluster.sh",
				"inherited_mysql_password") &&
			source_has("/scripts/map_worker_cluster.sh",
				"inherited_worker_token") &&
			source_has("/scripts/map_worker_cluster.sh",
				"inherited_active_ack"),
			".env可能覆盖运维显式指定的区服或一次性凭证");
			check("集群状态与重复apply使用受校验PID和监听端口而非screen外观",
			source_has("/scripts/map_worker_cluster.sh",
				"runtime_process_running") &&
			source_has("/scripts/map_worker_cluster.sh",
				"cluster_processes_running") &&
			source_has("/scripts/map_worker_cluster.sh",
				"ps -p \"$pid\" -o command=") &&
			source_has("/scripts/map_worker_cluster.sh",
				"port_is_listening \"$http_port\"") &&
			source_has("/scripts/map_worker_cluster.sh",
				"runtime_process_running coordinator") &&
			source_has("/scripts/map_worker_cluster.sh",
				"gateway: embedded in") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_controller_thread"),
				"screen会话消失时可能误报停止并重复启动同一端口");
			check("本地screen与容器background两种启动器共用PID栅栏",
				source_has("/scripts/map_worker_cluster.sh",
					"XIAND_MAP_WORKER_LAUNCHER must be screen or background") &&
				source_has("/scripts/map_worker_cluster.sh",
					"launch_detached()") &&
				source_has("/scripts/map_worker_cluster.sh",
					"nohup bash -lc") &&
				source_has("/scripts/map_worker_cluster.sh",
					"[[ \"$LAUNCHER\" == \"screen\" ]] || return 1") &&
				source_has("/scripts/map_worker_cluster.sh",
					"\"$ACTION\" != \"status\"") &&
				source_has("/scripts/map_worker_cluster.sh",
					"\"$ACTION\" != \"health\"") &&
				source_has("/docker/start-unified.sh",
					"XIAND_MAP_WORKER_LAUNCHER=background"),
				"容器缺少screen时只读诊断不可用，或worker启动绕过PID校验");
			check("worker健康失败只允许整组熔断回旧主进程",
				source_has("/scripts/map_worker_cluster.sh","cluster_health()") &&
				source_has("/scripts/map_worker_cluster.sh",
					"coordinator reports an unhealthy worker") &&
				source_has("/docker/start-unified.sh",
					"latch_active_fallback \"worker-health-failure\"") &&
				source_has("/docker/start-unified.sh",
					"if ! stop_cluster_safely \"$traffic_mode\"; then") &&
				source_has("/docker/start-unified.sh",
					"XIAND_MAP_WORKER_FAILOVER_SHUTDOWN") &&
				source_has("/scripts/map_worker_cluster.sh",
					"gateway_failover_quiesce") &&
				source_has("/docker/start-unified.sh",
					"persistent worker fallback latch found") &&
				source_has("/scripts/map_worker_cluster.sh",
					"tools/map_workers/test_startup.sh") &&
				source_has("/tools/map_workers/test_startup.sh",
					"latch stop legacy mode:legacy-fallback") &&
				source_has("/tools/map_workers/test_startup.sh",
					"must fail closed when worker shutdown is unproven") &&
				!source_has("/test_unit/test_pike_gateway.pike",
					"legacy_fallback_proxy"),
				"单请求重放到旧主进程可能造成装备、货币和战斗结果双写");
			check("编排变更单实例执行且全程固定同一代配置快照",
				source_has("/scripts/map_worker_cluster.sh",
					"acquire_orchestrator_lock") &&
				source_has("/scripts/map_worker_cluster.sh",
					"another map-worker apply/stop/recovery is running") &&
				source_has("/scripts/map_worker_cluster.sh",
					"config.$$.snapshot.json") &&
				source_has("/scripts/map_worker_cluster.sh",
					"One mutation uses one immutable config generation"),
				"并发apply/stop或启动中改配置可能混用两代worker数与端口");

		check("worker探测抖动有三次迟滞且持续失败仍由TTL摘除死节点",
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"PIKE_GATEWAY_MONITOR_FAILURES = 3") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_monitor_all_workers()") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_monitor_farm->run(") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_note_monitor_failure(worker_id,") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"if(isolate){") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"MAP_WORKER_HEARTBEAT_TTL = 20") &&
			source_has("/scripts/map_worker_cluster.sh",
				"gateway_workers = gateway.get(\"worker_requests\", {})") &&
			source_has("/scripts/map_worker_cluster.sh",
				"coordinator gateway reports an unreachable worker"),
			"单次抖动仍会停全服，或持续失联worker继续接收地图");

		check("两层master都禁止worker首次登录重复启动全局daemon但允许房间归属刷新器",
			source_has("/lowlib/system/master.pike",
				"Map-worker node skipping eager daemon") &&
			source_has("/gamelib/master.pike",
				"Map-worker node skipping eager daemon") &&
			source_has("/gamelib/master.pike","roomLeveld.pike") &&
			source_has("/gamelib/master.pike","timed_eventd.pike") &&
			source_has("/gamelib/master.pike","if(!map_worker_node)"),
			"人物首次登录可能复制家园保存、拍卖和地图刷新定时器");

		check("共享家园快照只允许home affinity owner持久化",
			source_has("/gamelib/single/daemons/homed.pike",
				"home_persistence_owner()") &&
			source_has("/gamelib/single/daemons/homed.pike",
				"local_worker_owns_room") &&
			source_has("/gamelib/single/daemons/homed.pike",
					"if(!home_persistence_owner())") &&
			source_has("/gamelib/single/daemons/homed.pike",
					"rejected shared snapshot mutation on non-owner worker") &&
			daemon->query_affinity_key(
				"/gamelib/d/home/worker_owner_probe","")=="home" &&
			daemon->query_affinity_key(
				"/gamelib/d/home/template/main","owner_a")=="home" &&
			daemon->query_affinity_key(
				"/gamelib/d/home/template/main","owner_b")=="home",
			"不同worker可能以各自过期缓存互相覆盖全局家园文件");

			check("并发新地图placement按generation串行发布到全部worker",
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"pike_gateway_assignment_lock") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"pike_gateway_assign_affinity") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"pike_gateway_sync_assignment(affinity,placement)"),
			"较旧generation可能晚到worker并使正常玩家请求失败");

		check("拓扑或热度只允许在所有worker空仓时冷重映射目录",
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"placement_topology_worker_count") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"placement_topology_requires_rebalance") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"affinity_heat_ready") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"\"version\":3") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_workers_are_cold") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"topology rebalance requires a cold worker inventory") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"heat_rebalance = heat_candidate && cold_workers") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"!pike_gateway_heat_rebalance_completed") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"assign_catalog(force_rebalance)"),
			"新增worker可能长期空闲，或恢复过程重映射含在线角色的地图");

			check("网络分区先自隔离卸载玩家且恢复前逐角色核对owner和epoch",
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"MAP_WORKER_LOCAL_CONTROL_TTL = 45") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"XIAND_WORKER_CONTROL_TIMEOUT") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"mark_local_control_isolated") &&
			source_has("/gamelib/clone/user.pike",
				"save_with_result(void|int autosave,void|int worker_fenced_save)") &&
			source_has("/gamelib/clone/user.pike",
				"query_local_player_epoch(query_name())>=1") &&
			source_has("/gamelib/clone/user.pike",
				"local_user_request_save_fence_valid(query_name())") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"saved = player->save_with_result(0,1)") &&
			source_has("/gamelib/clone/user.pike",
				"discard_stale_worker_copy") &&
			source_has("/gamelib/clone/user.pike",
				"SUMMOND->player_logout(query_name())") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"enforce_map_worker_control_fence") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"CONTROL_FENCE_DEFER") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"local_user_request_running") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"retire_abandoned_player_arrival") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_reconcile_recovered_worker") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"local_control_heartbeat") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"coordinator_epoch = (int)route[\"epoch\"]") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"if(!mappingp(result) || !(int)result[\"ok\"])") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"Public traffic only consumes the current capability") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"local_discard") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_recovered_worker_discards_copy_owned_by_new_epoch_elsewhere") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_duplicate_live_player_copies_are_discarded_without_saving") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_empty_recovery_cannot_resume_without_coordinator_generation_ack") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"archive is authoritative"),
			"旧worker可能恢复接流量后覆盖新owner的玩家或装备档案");

		check("恢复盘点会暂停新请求并等待在途事务完成",
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_active_requests") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_pause_routing()") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_recovery_waits_for_inflight_request_before_inventory") &&
			source_has("/scripts/map_worker_cluster.sh",
				"validate_gateway_stack") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"int main()") &&
			source_has("/scripts/map_worker_cluster.sh",
				"tools/map_workers/test_startup.sh") &&
			source_has("/scripts/map_worker_cluster.sh",
				"tools/map_workers/test_bootstrap.sh") &&
			source_has("/scripts/map_worker_cluster.sh",
				"topology_values=\"$(python3 -") &&
			source_has("/scripts/map_worker_cluster.sh",
				"recover-gateway") &&
			source_has("/scripts/map_worker_cluster.sh",
				"worker inventory reconciliation"),
			"恢复对账可能与玩家写操作并发或部署前漏跑网关测试");
		check("代理超时后按请求ID暂停全部新流量直到worker明确完成",
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"X-Xiand-Request-Id") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_quarantine_uncertain") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"local_request_status") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"begin_local_gateway_request") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"MAP_WORKER_MAX_LOCAL_REQUESTS = 65536") &&
			source_has("/gamelib/single/daemons/_http_api_mod/utils.pike",
				"finish_http_response") &&
			source_has("/gamelib/single/daemons/_http_api_mod/utils.pike",
				"complete_local_gateway_request(request_id)") &&
			source_has("/gamelib/single/daemons/_http_api_mod/utils.pike",
				"X-Xiand-Request-Accepted") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"A completed/expired request record must never leave") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"if(request_id!=\"\" && !running)") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"local_inflight") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_ensure_routing_ready()") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_request_queued_on_transaction_lock_rechecks_routing_gate") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_prefence_rejection_does_not_create_false_uncertain_request") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_invalid_internal_rpc_json_is_a_controlled_routing_failure") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_worker_response_does_not_duplicate_gateway_owned_headers") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_recover_local_players()") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_failed_generation_recovery_keeps_global_routing_paused"),
			"网关断线可能释放事务锁，而worker仍在发放装备或结算拍卖");

		check("共享账号的仓库钱包写操作按服务端权威owner串行",
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"resolve_account") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"account_id = pike_gateway_resolve_account(userid)") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"resolver->query_account_id_for_character(userid)") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_account_resolver_lock") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_account_resolver_daemon") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_shared_account_lock_identity_is_resolved_authoritatively"),
			"子角色首次并发可能绕过主账号事务锁并复制共享装备");
		check("共享账号切换worker时强制失效全部账号级进程缓存",
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"X-Xiand-Account-Cache-Token") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"accept_local_account_cache_token") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"accept_local_player_account_owner") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"invalidate_worker_account_cache(account_owner)") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"map_worker_player_account_authorized") &&
			source_has("/gamelib/single/daemons/account_storaged.pike",
				"void invalidate_worker_account_cache") &&
			source_has("/gamelib/single/daemons/account_walletd.pike",
				"void invalidate_worker_account_cache") &&
			source_has("/gamelib/single/daemons/account_characterd.pike",
				"void invalidate_worker_account_cache") &&
			source_has("/gamelib/single/daemons/_pet_mod/persistence.pike",
				"void invalidate_worker_account_cache") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"PETD->invalidate_worker_account_cache(account_owner)") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"PETD->mark_pet_player_runtime_stale(local_player)") &&
			source_has("/gamelib/single/daemons/_pet_mod/collection.pike",
				"int refresh_pet_player_runtime(object player)") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_lock_user_accounts(lock_users") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"referral_account") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"refresh_accounts+=({referral_account})") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_account_cache_capability_changes_only_when_worker_changes"),
			"不同worker可能用旧缓存覆盖共享装备或充值余额");
		check("共享充值钱包以文件锁和修订号CAS阻断跨进程旧快照覆盖",
			source_has("/gamelib/single/daemons/account_walletd.pike",
				"acquire_wallet_file_lock") &&
			source_has("/gamelib/single/daemons/account_walletd.pike",
				"file->lock()") &&
			source_has("/gamelib/single/daemons/account_walletd.pike",
				"SAVE_REVISION_CONFLICT") &&
			source_has("/gamelib/single/daemons/account_walletd.pike",
				"persisted_revision") &&
			source_has("/test_unit/test_account_recharge_wallet.pike",
				"test_wallet_revision_conflict_guard"),
			"管理员充值与玩家消费并发时可能丢失最新钱包余额");
		check("共享钱包命令后提交仍处于账号锁与请求完成栅栏内",
			source_has("/gamelib/single/daemons/yushid.pike",
				"finalize_wallet_payment_after_worker_request") &&
			source_has("/gamelib/single/daemons/yushid.pike",
				"MAP_WORKERD->query_node_role()!=\"worker\"") &&
				source_has("/gamelib/single/daemons/_http_api_mod/utils.pike",
					"retry_finish_http_response") &&
				source_has("/gamelib/single/daemons/_http_api_mod/utils.pike",
					"publish done even if the client has") &&
			source_has("/gamelib/single/daemons/_http_api_mod/utils.pike",
				"request_status[\"state\"]==\"running\"") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_wait_for_request_done") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_request_done_fence_waits_through_running_state") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_request_done_fence_fails_closed_on_unknown_status"),
			"延迟钱包回调可能在账号切到另一worker后用旧缓存覆盖余额");

		check("跨地图移动在move_object前阻断并由网关串行存档迁移后重放",
			source_has("/gamelib/clone/user.pike",
				"guard_local_player_move") &&
			source_has("/gamelib/clone/user.pike",
				"TIMED_EVENTD->guard_player_move(this_object(),dest)") &&
			source_has("/gamelib/clone/user.pike",
				"MAP_WORKER_REDIRECT_ERROR+\" dynamic room denied") &&
				source_has("/gamelib/clone/user.pike",
					"队伍状态正在同步到目标地图") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"primitive replica. The gateway") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"TERMD->query_termId") &&
			!source_has("/gamelib/clone/user.pike",
				"last_pos = room_path;") &&
			source_has("/lowlib/wapmud2/cmds/leave.pike",
				"if(!this_player()->move(dest))") &&
			source_has("/lowlib/wapmud2/cmds/leave.pike",
				"query_local_move_redirect") &&
			source_has("/lowlib/wapmud2/cmds/leave.pike",
				"detach_worker_move_followers") &&
			source_has("/lowlib/wapmud2/cmds/leave.pike",
				"自动跟随已安全解除") &&
			source_has("/gamelib/clone/user.pike",
				"void detach_worker_follow_links()") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"player->detach_worker_follow_links()") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_user_mutex(userid,account_id)->lock()") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"local_release") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"local_team_snapshot") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"local_team_apply") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"MAP_WORKERD->commit_handoff") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"\"epoch\":source_epoch") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"stale_local_epoch") &&
				source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
					"retire_worker_copy_after_save") &&
				source_has("/gamelib/clone/user.pike",
					"AUTOFIGHTD->cancel_server_autofight_tick(this_object())") &&
				source_has("/gamelib/single/daemons/http_api_daemon.pike",
					"AUTOFIGHTD->resume_worker_handoff(player)") &&
				source_has("/gamelib/clone/user.pike",
					"restore_persistent_activity_state") &&
				source_has("/gamelib/clone/user.pike",
					"auto_learn_runtime") &&
				source_has("/gamelib/single/daemons/autolearnd.pike",
					"prepare_worker_handoff") &&
				source_has("/gamelib/single/daemons/autolearnd.pike",
					"detach_worker_handoff") &&
				!source_has("/gamelib/single/daemons/autolearnd.pike",
					"user->reconnect(pswd)") &&
				source_has("/gamelib/clone/user.pike",
				"consume_worker_summon_handoff") &&
			source_has("/gamelib/single/daemons/summond.pike",
				"snapshot_worker_handoff") &&
			source_has("/gamelib/single/daemons/summond.pike",
				"Absolute expiry prevents") &&
			source_has("/test_unit/test_fangshi_summon_edges.pike",
				"test_worker_handoff_preserves_expiry_and_hp_ratio") &&
			!source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"player->remove();") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"complete_map_worker_arrival") &&
				source_has("/gamelib/clone/user.pike",
					"complete_static_worker_arrival") &&
				source_has("/gamelib/clone/user.pike",
					"(current_room && !current_room->is(\"menu\"))") &&
				source_has("/gamelib/single/daemons/http_api_daemon.pike",
					"if(!room || room->is(\"menu\"))") &&
			source_has("/gamelib/clone/user.pike",
				"if(worker_move_guard==2)") &&
				source_has("/gamelib/single/daemons/map_workerd.pike",
					"setup() first tries to enter the login menu") &&
				source_has("/gamelib/single/daemons/map_workerd.pike",
					"pending_arrival = normalize_room_location") &&
				source_has("/gamelib/single/daemons/map_workerd.pike",
					"lease[\"arrival_epoch\"] = epoch") &&
				source_has("/gamelib/clone/user.pike",
					"complete_same_worker_static_redirect") &&
			source_has("/gamelib/clone/user.pike",
				"SEASONALD->record_room_visit(this_object(),arrived_room)") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"local_redirect_complete") &&
			source_has("/gamelib/clone/user.pike",
				"move_err = catch { moved = ::move(ROOT+room_path); }") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"player->complete_static_worker_arrival") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"player->save_with_result(0,1)") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"SEASONALD->record_room_visit(player,room)") &&
			source_has("/gamelib/clone/user.pike",
				"consume_worker_summon_handoff(void|int worker_fenced_save)") &&
			!source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"output = execute_internal_command(player,\"start\")") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"X-Xiand-Arrival-Room") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"pike_gateway_reconciliation_pending(userid)") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"int require_settled") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"command_may_have_run") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"pre-command arrival remains pending") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"pike_gateway_deliver_background_arrival(userid,") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"pike_gateway_safe_view_request(method,path") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"\"\",account_id,\"view\"") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"coordinator arrival acknowledgement failed") &&
				source_has("/test_unit/test_pike_gateway.pike",
					"test_dynamic_clone_room_move_fails_closed_without_arrival_path") &&
				source_has("/test_unit/test_pike_gateway.pike",
					"test_migration_delivery_plan_distinguishes_old_and_current_commands"),
			"跨worker行走可能先移动、并发双活或未提交就加载目标人物");

		check("动态家园副本与活动移动失败不会提交半状态或残留绕过标志",
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"affinity function deliberately collapses every home") &&
			daemon->query_affinity_key(
				"/gamelib/d/home/template/main","visitor_a")=="home" &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"query_timed_event_session") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"query_player_affinity(player)") &&
			source_has("/gamelib/single/daemons/homed.pike",
				"Move first, then commit home membership") &&
			source_has("/gamelib/single/daemons/homed.pike",
				"add_user((string)player->query_name(),player)") &&
			source_has("/gamelib/cmds/home_view.pike",
				"HOMED->move_user_to_home(me,room)") &&
			source_has("/gamelib/cmds/home_visit.pike",
				"HOMED->move_user_to_home(me,room)") &&
			source_has("/gamelib/cmds/home_return.pike",
				"HOMED->move_user_to_home(me,room)") &&
			source_has("/gamelib/cmds/fb_entry.pike",
				"if(next_fb_id==\"\")") &&
			source_has("/gamelib/cmds/fb_entry.pike",
				"environment(me)!=room") &&
			source_has("/gamelib/single/daemons/_timed_event_mod/runtime.pike",
				"move_err = catch { moved = player->move(room); }") &&
			source_has("/gamelib/single/daemons/_timed_event_mod/runtime.pike",
				"m_delete_foruser(\"/tmp/timed_event_move_bypass\")"),
			"跨节点拒绝动态房间时可能丢失旧位置、污染成员表或永久绕过移动栅栏");

		check("限时活动先经静态入口汇聚到唯一owner再创建动态场地",
			daemon->query_affinity_key(
				"/gamelib/d/timed_event/tianheng_ingress.pike","")==
				"timed_event" &&
			source_has("/gamelib/single/daemons/_timed_event_mod/core.pike",
				"route_player_to_event_ingress") &&
			source_has("/gamelib/single/daemons/_timed_event_mod/runtime.pike",
				"/gamelib/d/timed_event/tianheng_ingress.pike") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"query_timed_event_ingress_id") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"!(int)pending_arrival[\"ok\"]") &&
			source_has("/gamelib/single/daemons/timed_eventd.pike",
				"local_timed_event_owner") &&
			source_has("/gamelib/single/daemons/timed_eventd.pike",
				"load_event_state(0)") &&
			source_has("/gamelib/single/daemons/_timed_event_mod/persistence.pike",
				"[TIMED_EVENTD][WRITE_FENCE]") &&
			source_has("/gamelib/single/daemons/_timed_event_mod/persistence.pike",
				"stage_reward_claim_ack") &&
			source_has("/gamelib/single/daemons/_timed_event_mod/persistence.pike",
				"consume_reward_claim_acks") &&
			source_has("/gamelib/single/daemons/_timed_event_mod/core.pike",
				"请先返回活动场地，再执行该操作"),
			"活动可能继续在多个worker各建一场、到达证明前跳入动态房或懒加载取消现场");

		check("死亡复活与挂机定时器产生的后台移动无需浏览器刷新也会收敛",
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"handle_map_worker_local_pending_routes") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"handle_map_worker_local_arrival") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"accept_local_player_account_owner") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"accept_local_account_cache_token") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"complete_map_worker_arrival(player,userid)") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_run_background_handoffs()") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"int require_settled") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_background_arrivals[userid]") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_background_arrival_uses_internal_cache_and_epoch_capabilities") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_timer_move_reconciles_under_lease_and_keeps_failed_arrival") &&
			source_has("/test_unit/test_pike_gateway.pike",
				"test_completed_public_arrival_clears_background_retry"),
			"后台移动可能永久滞留旧worker、依赖标签页刷新或恢复共享账号旧缓存");

		check("新人物在虚空阶段保留网关签名session亲和性并参与首次进图",
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"local_player_route_affinities") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"accept_local_player_route_affinity") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"query_local_player_route_affinity(userid)") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"New characters begin in LOW_VOID_OB") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"accept_local_player_route_affinity") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"query_local_player_route_affinity(userid)") &&
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"m_delete(local_player_route_affinities,userid)"),
			"首次建角可能停在虚空、live-lease无亲和性并触发worker隔离");
		check("HTTP人物入口使用私有session域并显式进入真实登录菜单",
			daemon->query_affinity_key("/gamelib/d/init",
				"xd99sessiontest")==
				daemon->query_player_session_affinity("xd99sessiontest") &&
			has_prefix(daemon->query_player_session_affinity(
				"xd99sessiontest"),"session:") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"ensure_http_player_routed_room") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"/gamelib/d/init") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"target_affinity!=routed_affinity") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"query_player_session_affinity(userid)"),
			"HTTP恢复人物仍可能停在LOW_VOID，或入口菜单跨进程形成共享状态");
		mapping arrival_bootstrap = ([
			"ok":1,"epoch":7,
			"room_path":"/gamelib/d/illusion_s1/moon_gate.pike",
		]);
		check("目标Worker恢复档案时不会把setup临时入口误记成反向迁移",
			daemon->test_arrival_bootstrap_move_guard(arrival_bootstrap,7,
				"/gamelib/d/init",0,0)==2 &&
			daemon->test_arrival_bootstrap_move_guard(arrival_bootstrap,7,
				"/gamelib/d/init",1,1)==2 &&
			daemon->test_arrival_bootstrap_move_guard(arrival_bootstrap,7,
				"/gamelib/d/illusion_s1/moon_gate.pike",0,0)==0 &&
			daemon->test_arrival_bootstrap_move_guard(arrival_bootstrap,8,
				"/gamelib/d/init",0,0)==0 &&
			source_has("/gamelib/clone/user.pike",
				"clear_local_move_redirect(query_name())"),
			"S1到达后可能残留返回登录入口的redirect，下一次请求把人物弹回入口");

		check("传送费用、目标与队伍身份均由服务端权威校验",
			source_has("/gamelib/cmds/transfer_to.pike",
				"transfer_destination_allowed") &&
			source_has("/gamelib/cmds/transfer_to.pike",
				"yushi_type!=1 || need_num!=1") &&
			source_has("/gamelib/cmds/transfer_to.pike",
				"Program.inherits(object_program(transfer),transfer_base)") &&
			source_has("/gamelib/cmds/transfer_to.pike",
				"remove_combine_item_transaction") &&
			source_has("/gamelib/cmds/transfer_to.pike",
				"rollback_combine_item_transaction") &&
			source_has("/gamelib/cmds/city_qge74hye.pike",
				"allowed_city_route") &&
			source_has("/gamelib/cmds/postcity.pike",
				"path = ROOT + me->relife") &&
			source_has("/gamelib/cmds/spec_yujian_to.pike",
				"to->query_term()!=me->query_term()") &&
			source_has("/gamelib/cmds/spec_yujian_to.pike",
				"me->get_cur_mofa()<300") &&
			!source_has("/gamelib/cmds/spec_yujian_to.pike",
				"object room = clone(path)"),
			"可伪造客户端链接实现免费飞行、越级目的地或飞向非队友");

		check("传送和家园移动先确认成功再提交位置、成员与冷却副作用",
			source_has("/gamelib/cmds/qge74hye.pike",
				"int was_in_home = me->if_in_home()") &&
			source_has("/gamelib/cmds/qge74hye.pike",
				"if(move_err || !moved)") &&
			source_has("/gamelib/cmds/home_return_to_flat.pike",
				"flatPath!=(string)old_room->query_flatPath()") &&
			source_has("/gamelib/cmds/home_return_to_flat.pike",
				"HOMED->clear_user(me)") &&
			source_has("/gamelib/cmds/home_enter.pike",
				"HOMED->move_user_to_home(me,room)") &&
			source_has("/gamelib/cmds/home_move.pike",
				"HOMED->move_user_to_home(me,room)") &&
			source_has("/gamelib/single/daemons/homed.pike",
				"else\n\t\t\tclear_user(me);") &&
			source_has("/gamelib/cmds/waihai_qge74hye.pike",
				"path!=\"waihai/wenshuidai\"") &&
			source_has("/gamelib/cmds/waihai_qge74hye.pike",
				"is_valid_relife_path"),
			"移动被拒绝时可能先清家园、写冷却、改last_pos或接受伪造复活路径");

		check("挂机分流与城池热更新不会把在线人物跨worker临时搬运",
			source_has("/gamelib/single/daemons/map_workerd.pike",
				"local_worker_owns_room") &&
			source_has("/gamelib/single/daemons/autofightd.pike",
				"Let qge74hye") &&
			source_has("/gamelib/single/daemons/autofightd.pike",
				"environment(me)!=room") &&
			source_has("/gamelib/single/daemons/cityd.pike",
				"worker-local staging room") &&
			source_has("/gamelib/single/daemons/cityd.pike",
				"staged object return failed") &&
			source_has("/gamelib/cmds/wiz_update.pike",
				"多 worker 模式禁止单节点热更新") &&
			source_has("/gamelib/cmds/wiz_summon.pike",
				"目标当前无法安全跨地图召唤") &&
			source_has("/gamelib/cmds/wiz_goto.pike",
				"目标房间当前无法安全到达"),
			"临时房、热更新或管理员命令可能绕开人物租约并留下双活/半状态");

		check("同房间双账号事务开放直赠交易且跨worker请求失败关闭",
			source_has("/gamelib/single/daemons/player_transferd.pike",
				"same_local_room") &&
			source_has("/gamelib/single/daemons/player_transferd.pike",
				"trylock()") &&
			source_has("/gamelib/single/daemons/player_transferd.pike",
				"save_player(seller)") &&
			source_has("/gamelib/single/daemons/player_transferd.pike",
				"save_player(buyer)") &&
			source_has("/gamelib/single/daemons/player_transferd.pike",
				"create_gift_offer") &&
			source_has("/gamelib/single/daemons/player_transferd.pike",
				"create_trade_offer") &&
			source_has("/gamelib/single/daemons/player_transferd.pike",
				"offer[\"item\"]==query_owned_item") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_player_transfer_target") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_lock_user_pair(userid,account_id") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"\"batch_gift_ok\"") &&
			source_has("/gamelib/cmds/sendother_ok.pike",
				"PLAYER_TRANSFERD->execute_gift") &&
			source_has("/gamelib/cmds/trade.pike",
				"PLAYER_TRANSFERD->execute_trade") &&
			!source_has("/gamelib/cmds/sendother_to.pike",
				"find_player(user_name)") &&
			!source_has("/gamelib/cmds/trade.pike",
				"find_player(user_name)") &&
			source_has("/gamelib/cmds/mgr_map_workers.pike",
				"跨房间或跨 Worker 仍失败关闭"),
			"双账号锁、双档案结算或同房间边界不完整");

			check("账号会话API固定主worker且冷token解析不全局锁人物分片",
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_account_path((string)snapshot[\"path_only\"])") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_account_management_lock->lock()") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"local_account_session_owner") &&
			!source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"foreach(pike_gateway_user_locks,object mutex)") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_proxy(pike_gateway_primary") &&
				source_has("/test_unit/test_pike_gateway.pike",
					"test_token_only_account_maintenance_waits_for_character_write") &&
				source_has("/test_unit/test_pike_gateway.pike",
					"test_conflicting_valid_identity_fields_are_rejected") &&
				source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
					"gameplay token owner mismatch"),
			"账号登录会话可能分散到多进程或与角色写操作并发");

		check("worker公开HTTP必须经回环网关且内部RPC不会被公网反代",
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"map_worker_gateway_request_authorized") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"has_prefix(path_only,\"/internal/\")") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"!has_prefix(lowered,\"x-xiand-\")") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_request_farm = Thread.Farm()") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_pending_requests<pike_gateway_max_requests") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_worker_request_limit") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"pike_gateway_worker_circuit_until") &&
			source_has("/gamelib/single/daemons/_http_api_mod/pike_gateway.pike",
				"XIAND_GATEWAY_MAX_REQUESTS"),
			"外部可伪造worker租约头或访问内部控制面");
		check("内部RPC拒绝日志只记录长度和匹配结果、不泄露令牌内容",
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"configured_len=%d supplied_len=%d") &&
			source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"req->get_ip()") &&
			!source_has("/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike",
				"configured=%s"),
			"认证诊断可能把worker密钥写进日志");
		check("coordinator详细健康检查不懒加载游戏世界daemon",
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"health_node_role!=\"gateway\"") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"not_collected_on_gateway") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"Loading gameplay") &&
			source_has("/gamelib/single/daemons/http_api_daemon.pike",
				"public gateway"),
			"监控可能在启动后加载地图/任务/技能/挂机daemon并阻塞公网gateway");
	};
	if(err)
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
	if(err)
		check("运行时无异常",0,error_desc);
	// The test registers synthetic nodes, placements and leases. Keep all of
	// that state inside this disposable instance so a successful TestUnit run
	// cannot pollute the live standalone MAP_WORKERD singleton.
	destruct(daemon);

	werror("地图 Worker：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
