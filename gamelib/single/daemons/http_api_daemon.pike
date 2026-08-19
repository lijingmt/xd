/**
 * ========================================================================
 * HTTP API Daemon - Vue UI Backend (Adapted for xiand)
 * ========================================================================
 *
 * 提供Vue前端与MUD游戏服务器之间的HTTP API接口
 *
 * 架构：
 *   Vue Browser → HTTP API (8888) → Virtual Connection → MUD Game (5555)
 *
 * 模块化设计：
 *   - config.pike: 配置常量
 *   - utils.pike: 工具函数
 *   - virtual_conn.pike: 虚拟连接池
 *   - auth.pike: 认证功能
 *   - command_queue.pike: 异步请求队列
 *   - html_renderer.pike: HTML渲染
 *   - rate_limit.pike: 速率限制
 *
 * ========================================================================
 * @author  Claude Code
 * @version 3.0.0 (Modular Refactor - xiand)
 * @since   2024
 * ========================================================================
 */

#include <globals.h>
#include <lowlib.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define ASYNC_IOD ((object)(ROOT "/gamelib/single/daemons/async_iod.pike"))

// ========================================================================
// HTTP API 日志函数 (必须在 include 之前定义)
// ========================================================================

/** HTTP API 调试开关：1=启用日志(werror输出), 0=关闭日志 */
constant HTTP_API_DEBUG = 0;

/**
 * HTTP API 专用日志函数 - 根据调试开关输出
 * @param fmt 格式化字符串
 * @param args ... 参数
 */
void http_werror(string fmt, mixed ... args)
{
    string lowered = lower_case(fmt || "");
    int important = search(lowered," error")!=-1 ||
        search(lowered,"exception")!=-1 ||
        search(lowered,"fatal")!=-1 ||
        search(lowered,"unavailable")!=-1 ||
        search(lowered,"failed to")!=-1;
    if(HTTP_API_DEBUG || important) {
        werror("[HTTP_API]" + sprintf(fmt, @args));
    }
}

/**
 * Protocols.HTTP 的 remote_addr 使用 "IP 端口" 格式。限流和本机授权
 * 必须丢弃临时源端口，否则每次新建连接都会得到一个新的限流键。
 */
string normalize_http_client_ip(string address)
{
    string trimmed = String.trim_all_whites(address || "");
    if(trimmed=="")
        return "unknown";
    array(string) parts = trimmed / " ";
    string ip = parts[0];
    if(sizeof(ip)>=2 && ip[0]=='['){
        int bracket = search(ip,"]");
        if(bracket>1)
            ip = ip[1..bracket-1];
    }
    else{
        string host = "";
        int port = 0;
        if(sscanf(ip,"%s:%d",host,port)==2 && search(host,":")==-1)
            ip = host;
    }
    return ip;
}

// ========================================================================
// 导入模块
// ========================================================================

#include "_http_api_mod/config.pike"
#include "_http_api_mod/utils.pike"
#include "_http_api_mod/virtual_conn.pike"
#include "_http_api_mod/auth.pike"
#include "_http_api_mod/command_queue.pike"
#include "_http_api_mod/thread_manager.pike"
#include "_http_api_mod/html_renderer.pike"
#include "_http_api_mod/rate_limit.pike"
#include "_http_api_mod/account_characters.pike"
#include "_http_api_mod/equipment_panel.pike"
#include "_http_api_mod/pike_gateway.pike"
#include "_http_api_mod/map_worker_rpc.pike"

// ========================================================================
// 全局变量
// ========================================================================

/** HTTP服务器端口对象 */
Protocols.HTTP.Server.Port http_port;

/** API只读模式 */
int api_only_mode = 1;

/** HTTP API启动时间 */
int http_api_start_time = 0;
int http_listen_port = HTTP_PORT;
string http_listen_host = "0.0.0.0";

/** HTTP 请求性能统计 */
int http_request_count = 0;
int http_slow_request_count = 0;
int http_max_request_ms = 0;
int http_last_slow_time = 0;
string http_last_slow_path = "";
int pagination_snapshot_created;
int pagination_snapshot_missing;

/** HTTP API 登录待定标记 - 用于 login_check.pike 检测是否为 HTTP API 模式 */
mapping(string:int) http_api_login_pending = ([]);
Thread.Mutex http_api_login_pending_lock = Thread.Mutex();

// 设置 HTTP API 登录标记
void set_http_api_login_pending(string userid, int value) {
    object key = http_api_login_pending_lock->lock();
    http_api_login_pending[userid] = value;
    destruct(key);
}

// 查询 HTTP API 登录标记
int query_http_api_login_pending(string userid) {
    object key = http_api_login_pending_lock->lock();
    int result = http_api_login_pending[userid] || 0;
    destruct(key);
    return result;
}

// 清除 HTTP API 登录标记
void clear_http_api_login_pending(string userid) {
    object key = http_api_login_pending_lock->lock();
    m_delete(http_api_login_pending, userid);
    destruct(key);
}

void record_pagination_snapshot_created()
{
    pagination_snapshot_created++;
}

void record_pagination_snapshot_miss()
{
    pagination_snapshot_missing++;
    if(pagination_snapshot_missing%64==0)
        werror("[HTTP_API][PAGINATION] snapshot_missing=%d snapshot_created=%d\n",
            pagination_snapshot_missing,pagination_snapshot_created);
}

mapping query_pagination_status()
{
    return ([
        "snapshots_created":pagination_snapshot_created,
        "snapshot_missing":pagination_snapshot_missing,
    ]);
}

// ========================================================================
// 经验加成配置查询
// ========================================================================

/**
 * 查询 HTTP API 经验加成是否启用
 * @return 1=启用, 0=禁用
 */
int query_exp_bonus_enabled() {
    return HTTP_API_EXP_BONUS_ENABLED;
}

/**
 * 查询 HTTP API 经验加成倍率
 * @return 倍率 (100=原始, 150=1.5倍)
 */
int query_exp_bonus_rate() {
    return HTTP_API_EXP_BONUS_RATE;
}

// ========================================================================
// 初始化
// ========================================================================

protected void create()
{
    http_api_start_time = time();
    http_listen_port = query_configured_http_port();
    http_listen_host = query_configured_http_host();
    init_parallel_command_farm();
    refresh_button_grade_snapshot();
    werror("========================================\n");
    werror("[HTTP_API] Daemon Loading...\n");
    werror("[HTTP_API] HTTP_PORT = %d\n", http_listen_port);
    werror("[HTTP_API] HTTP_API_DEBUG = %d\n", HTTP_API_DEBUG);
    werror("[HTTP_API] EXP_BONUS_ENABLED = %d\n", HTTP_API_EXP_BONUS_ENABLED);
    werror("[HTTP_API] EXP_BONUS_RATE = %d%%\n", HTTP_API_EXP_BONUS_RATE);
    werror("[HTTP_API] ROOT = %s\n", ROOT);
    werror("[HTTP_API] SROOT = %s\n", SROOT);
    werror("========================================\n");

    call_out(start_server, 5);
    // 定期清理
    call_out(cleanup_rate_limits, 60);
    call_out(cleanup_idle_connections, 60);
    // 启动队列处理
    call_out(start_worker_thread, 10);
    call_out(cleanup_old_results, RESULT_CLEANUP_INTERVAL);
    // Distributed workers self-fence before the coordinator can reassign an
    // expired owner. Standalone servers return immediately in this check.
    call_out(enforce_map_worker_control_fence, 2);
    // The coordinator also owns the transparent public Pike gateway. Shadow
    // mode starts only its control loop and deliberately leaves port 8888 to
    // the legacy standalone process.
    call_out(init_pike_gateway, 1);
}

void start_server()
{
    werror("[HTTP_API] start_server() called, http_port=%O\n", http_port);
    if(http_port) {
        werror("[HTTP_API] Server already running!\n");
        return;
    }

    werror("[HTTP_API] Creating HTTP.Server.Port on %s:%d\n",
        http_listen_host,http_listen_port);
    mixed err = catch {
        http_port = Protocols.HTTP.Server.Port(handle_request,
            http_listen_port, http_listen_host);
    };

    if(err) {
        werror("[HTTP_API] ERROR starting server: %O\n", err);
    } else {
        werror("[HTTP_API] Successfully started on port %d\n", http_listen_port);
        werror("[HTTP_API] Listening on http://%s:%d\n",
            http_listen_host,http_listen_port);
        werror("[HTTP_API] API Endpoints available:\n");
        werror("[HTTP_API]   - GET  /health\n");
        werror("[HTTP_API]   - GET  /api/partitions\n");
        werror("[HTTP_API]   - GET  /api/challenge\n");
        werror("[HTTP_API]   - POST /api/login\n");
        werror("[HTTP_API]   - GET  /api (execute command)\n");
        werror("========================================\n");
    }
}

void set_api_only_mode(int mode)
{
    api_only_mode = mode;
}

// ========================================================================
// 命令执行系统
// ========================================================================

/**
 * 执行系统级命令
 */
string execute_system_command(string cmd)
{
    string output = "";
    array args = cmd / " ";
    string cmd_name = args[0];

    string cmd_file = ROOT + "/gamelib/cmds/" + cmd_name + ".pike";
    object cmd_obj = load_object(cmd_file);

    if(cmd_obj) {
        mixed err = catch {
            mixed result = cmd_obj->main(cmd[sizeof(cmd_name)..]);
            if(stringp(result)) {
                output += result;
            }
        };
        if(err) {
            http_werror(" System command error: %s\n", describe_error(err));
            output += "命令执行错误\n";
        }
    } else {
        output += "未知系统命令: " + cmd_name + "\n";
    }

    return output;
}

/**
 * 执行内部命令 (通过玩家的command方法)
 */
string execute_internal_command(object player, string cmd)
{
    // http_werror(" execute_internal: %s\n", cmd);

    // 解析命令
    string first_word = cmd;
    string target_arg = "";
    int space_pos = search(cmd, " ");
    if(space_pos > 0) {
        first_word = cmd[0..space_pos-1];
        target_arg = cmd[space_pos+1..];
    }

    // 保存原始this_player
    object original_this_player = this_player();
    set_this_player(player);

    // 创建虚拟连接对象来捕获输出
    object buffer_conn = BufferConnection();

    // xiand: 使用绝对路径加载 CONND
    object connd = find_object(SROOT + "/connd.pike");
    if(!connd) {
        connd = load_object(SROOT + "/connd.pike");
    }

    // 保存原始连接并设置虚拟连接
    object original_conn = connd->query_conn(player);
    connd->set_conn(player, buffer_conn);

    // 直接调用command()
    mixed err = catch {
		int ingress_moved = 0;
		// A cross-worker timed-event join first lands in a signed static
		// ingress. Never leave that recovery room during the arrival proof; on
		// the gateway's following safe view, resume the join automatically.
		object ingress_room = environment(player);
		mapping pending_arrival = MAP_WORKERD->query_local_player_arrival(
			(string)player->query_name());
		if((first_word=="look" || first_word=="l") && ingress_room &&
		   functionp(ingress_room->query_timed_event_ingress_id) &&
		   !(int)pending_arrival["ok"]){
			string ingress_event =
				(string)ingress_room->query_timed_event_ingress_id();
			if(ingress_event=="tianheng" || ingress_event=="jiuyao"){
				player->command("timed_event join "+ingress_event);
				ingress_moved = environment(player)!=ingress_room;
			}
		}
		// FBD 动态幻境沿用限时活动的安全模型。只有协调器 arrival
		// 已确认后才自动续办，避免目标 Worker 在玩家唯一归属尚未
		// 证明时创建克隆房和房内奖励状态。
		if(!ingress_moved && (first_word=="look" || first_word=="l") &&
		   ingress_room && functionp(ingress_room->is_fb_worker_ingress) &&
		   ingress_room->is_fb_worker_ingress() &&
		   !(int)pending_arrival["ok"]){
			string ingress_fb_name=FBD->query_fb_name_by_id(player->fb_id);
			if(ingress_fb_name!=""){
				player->command("fb_entry "+ingress_fb_name+" 0 0");
				ingress_moved=environment(player)!=ingress_room;
			}
		}
		// join already renders the destination. If it failed, keep the outer
		// look so the ingress recovery links remain usable.
		if(!ingress_moved)
			player->command(cmd);
        // http_werror(" command() executed\n");
    };

    // 在恢复 this_player/连接前完成输出兜底；房间描述依赖当前玩家
    // 上下文，过早恢复会让 query_desc() 收到 NULL this_player。
    string output_buffer = buffer_conn->get_output();

    mixed fallback_err;
    if(!err && sizeof(output_buffer) == 0) {
        fallback_err = catch {
            if((first_word == "look" || first_word == "l") &&
               sizeof(target_arg) > 0)
                output_buffer = get_target_info(player, target_arg);
            else
                output_buffer = get_room_info(player);
        };
    }

    // 无论命令或兜底是否异常，都恢复原始连接和 this_player。
    connd->set_conn(player, original_conn);
    set_this_player(original_this_player);

    if(err) {
        http_werror(" Command error\n");
        output_buffer += "命令执行错误\n";
    }
    if(fallback_err) {
        http_werror(" Command fallback error\n");
        output_buffer += "命令执行错误\n";
    }

    return output_buffer;
}

/**
 * HTTP players do not pass through socket exec(), so a freshly restored
 * object must explicitly enter its signed route. Session leases use the
 * private login menu; established static-map leases may restore only an exact
 * same-affinity last_pos. Dynamic or mismatched routes fail closed.
 */
private int ensure_http_player_routed_room(object player)
{
	object target_room;
	string userid;
	string routed_affinity;
	string target_path;
	string target_affinity;
	int moved;
	mixed err;
	if(!player)
		return 0;
	if(MAP_WORKERD->query_player_affinity(player)!="")
		return 1;
	userid = (string)player->query_name();
	routed_affinity = MAP_WORKERD->query_local_player_route_affinity(userid);
	if(MAP_WORKERD->query_node_role()!="worker" ||
	   has_prefix(routed_affinity,"session:"))
		target_path = "/gamelib/d/init";
	else{
		target_path = (string)(player->last_pos || "");
		if(!has_prefix(target_path,"/gamelib/d/") ||
		   search(target_path,"..")!=-1 || search(target_path,"#")!=-1)
			return 0;
		target_affinity = MAP_WORKERD->query_affinity_key(target_path);
		if(routed_affinity=="" || target_affinity!=routed_affinity)
			return 0;
	}
	err = catch { target_room=(object)(ROOT+target_path); };
	if(err || !target_room)
		return 0;
	http_werror("[HTTP_ROUTE_RESTORE] userid=%s affinity=%s target=%s\n",
		userid,routed_affinity!="" ? routed_affinity : "standalone",target_path);
	err = catch { moved=player->move(target_room); };
	return !err && moved && environment(player)==target_room;
}

/**
 * 获取目标对象信息
 */
string get_target_info(object player, string target_name)
{
    string output = "";
    object room = environment(player);
    mixed target;

    if(!room) {
        return "你处于虚空中。\n[返回:look]";
    }

    array inv = all_inventory(room,player);
    foreach(inv, object ob) {
        if(ob == player) continue;
        string ob_name = functionp(ob->query_name) ? ob->query_name() : "";
        if(ob_name == target_name) {
            target = ob;
            break;
        }
        if(functionp(ob->query_name_cn) && ob->query_name_cn() == target_name) {
            target = ob;
            break;
        }
        if(functionp(ob->query_short)) {
            string short_name = ob->query_short();
            if(search(short_name, target_name) >= 0) {
                target = ob;
                break;
            }
        }
    }

    if(!target) {
        return sprintf("这里没有 %s。\n[返回:look]", target_name);
    }

    string name = "";
    if(functionp(target->query_short)) {
        name = target->query_short();
    } else if(functionp(target->query_name_cn)) {
        name = target->query_name_cn();
    } else {
        name = target_name;
    }
    output += name + "\n";

    if(functionp(target->query_long)) {
        string long_desc = target->query_long();
        if(long_desc && sizeof(long_desc) > 0) {
            output += long_desc + "\n";
        }
    }
    if(functionp(target->query_desc)) {
        string desc = target->query_desc();
        if(desc && sizeof(desc) > 0) {
            output += desc + "\n";
        }
    }

    int is_npc = 0;
    if(functionp(target->attack) || functionp(target->kill) ||
       (target->query_hp && functionp(target->query_hp))) {
        is_npc = 1;
    }

    output += "\n";
    if(is_npc) {
        output += "[切磋:" + target_name + "]\n";
        output += "[杀戮:" + target_name + "]\n";
    }
    output += "[返回:look]";

    return output;
}

/**
 * 获取房间信息
 */
string get_room_info(object player)
{
    string output = "";
    object room = environment(player);

    if(!room) {
        return "你处于虚空中...\n";
    }

    if(functionp(room->query_short)) {
        output += room->query_short() + "\n";
    }

    if(functionp(room->query_desc)) {
        string desc = room->query_desc();
        if(desc && sizeof(desc) > 0) {
            output += desc + "\n";
        }
    }
    else if(functionp(room->query_long)) {
        output += room->query_long() + "\n";
    }

    if(functionp(room->query_exits)) {
        mapping exits = room->query_exits();
        if(exits && sizeof(exits) > 0) {
            output += "\n";
            foreach(indices(exits), string dir) {
                output += sprintf("[%s:go %s]", dir, dir);
            }
        }
    }

    array inv = all_inventory(room,player);
    if(sizeof(inv) > 1) {
        output += "\n\n";
        foreach(inv, object ob) {
            if(ob != player && functionp(ob->query_short)) {
                string name = ob->query_short();
                if(name) {
                    string cmd_name = name;
                    if(functionp(ob->query_name)) {
                        string ob_name = ob->query_name();
                        if(ob_name && sizeof(ob_name) > 0) {
                            cmd_name = ob_name;
                        }
                    }
                    output += sprintf("[%s:look %s]", name, cmd_name);
                }
            }
        }
    }

    return output;
}

/**
 * 登录并执行命令 (主入口函数)
 *
 * 线程路由策略：所有人物/世界命令只允许在主 Backend 执行；
 * Thread.Farm 仅处理已经快照化的文本解析和 JSON 编码。
 */
string execute_command(string userid, string password, string cmd)
{
    if(!LOGICALZONED->login_allowed(userid))
        return "{\"error\":\"该逻辑区尚未开放或正在维护\"}";
    // 使用线程管理器路由执行
    return route_and_execute(userid, password, cmd);
}

/** Complete one durable cross-worker arrival instead of replaying movement. */
private mapping complete_map_worker_arrival(object player,string userid)
{
    mapping arrival = MAP_WORKERD->query_local_player_arrival(userid);
    object room;
    string affinity;
    string output = "";
    int saved;
    mixed err;
    if(!(int)arrival["ok"])
        return (["handled":0]);
    room = environment(player);
    affinity = room ? MAP_WORKERD->query_player_affinity(player) : "";
    // A background handoff restores the sole target object directly from its
    // archive, so it legitimately has no environment yet. The player method
    // still requires the exact installed userid/epoch/room capability and
    // rejects every object that is already in a real world room.
    if(!room || room->is("menu")){
        if(!functionp(player->complete_static_worker_arrival) ||
           !player->complete_static_worker_arrival(
                (string)arrival["room_path"])){
            werror("[MAP_WORKER][ARRIVAL_FAILED] userid=%s stage=move epoch=%d\n",
                userid,(int)arrival["epoch"]);
            remove_virtual_connection(userid);
            MAP_WORKERD->clear_local_player_arrival(userid);
            if(functionp(player->discard_stale_worker_copy))
                player->discard_stale_worker_copy();
            else
                destruct(player);
            return (["handled":1,
                "output":"{\"error\":\"跨地图到达校验失败，请重试\"}"]);
        }
        room = environment(player);
        affinity = room ? MAP_WORKERD->query_player_affinity(player) : "";
    }
    if(affinity!=(string)arrival["affinity"]){
        werror("[MAP_WORKER][ARRIVAL_FAILED] userid=%s stage=affinity epoch=%d\n",
            userid,(int)arrival["epoch"]);
        remove_virtual_connection(userid);
        MAP_WORKERD->clear_local_player_arrival(userid);
        if(functionp(player->discard_stale_worker_copy))
            player->discard_stale_worker_copy();
        else
            destruct(player);
        return (["handled":1,
            "output":"{\"error\":\"跨地图到达校验失败，请重试\"}"]);
    }
    if(functionp(player->consume_worker_summon_handoff) &&
       !player->consume_worker_summon_handoff(1)){
        werror("[MAP_WORKER][ARRIVAL_FAILED] userid=%s stage=summon_save epoch=%d\n",
            userid,(int)arrival["epoch"]);
        remove_virtual_connection(userid);
        MAP_WORKERD->clear_local_player_arrival(userid);
        if(functionp(player->discard_stale_worker_copy))
            player->discard_stale_worker_copy();
        else
            destruct(player);
        return (["handled":1,
            "output":"{\"error\":\"跨地图召唤状态落盘失败，请重试\"}"]);
    }
    output = execute_internal_command(player,"look");
    // Clear the one-shot status capability in the same atomic save that proves
    // the final destination. A failed save leaves the previous archive intact
    // so a retried arrival can restore timed medicine/home effects again.
    if(functionp(player->finalize_worker_status_effect_handoff))
        player->finalize_worker_status_effect_handoff();
    // The authenticated gateway already committed this exact target epoch and
    // room capability. This is the target's one mandatory arrival save, so it
    // must remain valid while a control heartbeat is rolling over.
    err = catch { saved = player->save_with_result(0,1); };
    if(err || !saved){
        werror("[MAP_WORKER][ARRIVAL_FAILED] userid=%s stage=save epoch=%d error=%s\n",
            userid,(int)arrival["epoch"],err ? describe_error(err) : "false");
        remove_virtual_connection(userid);
        MAP_WORKERD->clear_local_player_arrival(userid);
        if(functionp(player->discard_stale_worker_copy))
            player->discard_stale_worker_copy();
        else
            destruct(player);
        return (["handled":1,
            "output":"{\"error\":\"跨地图到达存档失败，请重试\"}"]);
    }
    MAP_WORKERD->clear_local_player_arrival(userid);
    // Target arrival uses inherited ::move() and therefore bypasses the
    // ordinary user::move() visit hook. Record only after the exact arrival
    // archive is durable and the local arrival fence has been consumed.
    SEASONALD->record_room_visit(player,room);
    // Register only after the final arrival archive is durable. This prevents a
    // background flushview from racing the one-shot handoff capability while also
    // ensuring browser-background AFK continues on the destination worker.
    if(functionp(player->query_autofight) &&
       player->query_autofight()=="enable"){
        int resumed = 0;
        mixed resume_err = catch {
            resumed = AUTOFIGHTD->resume_worker_handoff(player);
        };
        if(resume_err || !resumed)
            werror("[MAP_WORKER][AFK_RESUME_FAILED] userid=%s epoch=%d error=%s\n",
                userid,(int)arrival["epoch"],resume_err ?
                    describe_error(resume_err) : "false");
    }
    return (["handled":1,"output":output]);
}

/** A newly loaded player must match the gateway's authoritative account lock. */
private int map_worker_player_account_authorized(object player,string userid)
{
    string expected;
    string actual;
    if(MAP_WORKERD->query_node_role()!="worker")
        return 1;
    expected = MAP_WORKERD->query_local_player_account_owner(userid);
    actual = player && functionp(player->query_account_owner) ?
        (string)player->query_account_owner() : "";
    return expected!="" && actual==expected;
}

private string discard_map_worker_account_mismatch(object player,string userid)
{
    remove_virtual_connection(userid);
    MAP_WORKERD->clear_local_player_epoch(userid);
    if(player && functionp(player->discard_stale_worker_copy))
        player->discard_stale_worker_copy();
    else if(player)
        destruct(player);
    return "{\"error\":\"账号归属校验失败，请重试\"}";
}

// ========================================================================
// 同步版本的命令执行函数 (供线程管理器调用)
// ========================================================================

/**
 * 同步执行命令（由线程管理器确认在主 Backend 后调用）
 */
string execute_command_sync(string userid, string password, string cmd)
{
    // http_werror(" execute_command_sync: %s for %s\n", cmd, userid);

    // 立即更新连接活跃时间 - 确保活跃用户不会被踢出
    update_connection_time(userid);

    mixed err = catch {
        // 检查是否已有虚拟连接
        object player = get_player_from_connection(userid);
        if(player) {
            if(!map_worker_player_account_authorized(player,userid))
                return discard_map_worker_account_mismatch(player,userid);
            mapping arrival = complete_map_worker_arrival(player,userid);
            if((int)arrival["handled"])
                return (string)arrival["output"];
            if(!ensure_http_player_routed_room(player))
                return "{\"error\":\"登录入口路由失败，请重试\"}";
            if(functionp(player->consume_worker_summon_handoff) &&
               !player->consume_worker_summon_handoff())
                return "{\"error\":\"跨地图召唤状态恢复失败，请重试\"}";
            return execute_internal_command(player, cmd);
        }

        // 设置 HTTP API 登录标记（让 login_check 知道这是 HTTP API 模式）
        set_http_api_login_pending(userid, 1);

        // 生成 session ID
        string session_id = sprintf("%d", time());

        // 调用 login_check 进行完整登录（包含密码验证和 setup）
        // login_check 会：
        // 1. 验证密码
        // 2. 创建/找到玩家对象
        // 3. 调用 setup()
        // 4. 检查 http_api_login_pending 标记，跳过 exec()
        // 5. 将玩家存入虚拟连接池
        string login_arg = sprintf("gamelib %s %s %s", userid, password, session_id);
        object login_cmd = load_object(ROOT + "/lowlib/system/cmds/login_check.pike");
        if(login_cmd) {
            login_cmd->main(login_arg);
        }

        // 清除登录标记
        clear_http_api_login_pending(userid);

        // 从虚拟连接池获取登录后的玩家
        player = get_player_from_connection(userid);

        if(!player) {
            return "{\"error\":\"登录失败\"}";
        }

        if(!map_worker_player_account_authorized(player,userid))
            return discard_map_worker_account_mismatch(player,userid);

        mapping arrival = complete_map_worker_arrival(player,userid);
        if((int)arrival["handled"])
            return (string)arrival["output"];

        if(!ensure_http_player_routed_room(player))
            return "{\"error\":\"登录入口路由失败，请重试\"}";

        if(functionp(player->consume_worker_summon_handoff) &&
           !player->consume_worker_summon_handoff())
            return "{\"error\":\"跨地图召唤状态恢复失败，请重试\"}";

        return execute_internal_command(player, cmd);
    };

    // 清除登录标记（即使出错也要清除）
    clear_http_api_login_pending(userid);

    if(err) {
        // Keep credentials out of logs, but retain the Pike source location;
        // a generic line made first-login failures impossible to diagnose.
        http_werror(" execute_command_sync error: %s\n",
            replace(describe_error(err),({"\r","\n"}),({" "," "})));
        return "{\"error\":\"命令执行失败\"}";
    }
}

/** 旧测试/内部兼容入口；仍强制走 Backend 世界命令门禁。 */
string execute_internal_command_sync(string userid, string password, string cmd)
{
    return execute_core_command(userid,password,cmd);
}

// ========================================================================
// HTTP路由
// ========================================================================

void record_http_request_timing(string method, string path, int started_at)
{
    int elapsed_ms = (gethrtime()-started_at)/1000;

    http_request_count++;
    if(elapsed_ms > http_max_request_ms)
        http_max_request_ms = elapsed_ms;
    if(elapsed_ms >= HTTP_SLOW_REQUEST_MS){
        http_slow_request_count++;
        http_last_slow_time = time();
        http_last_slow_path = (method || "")+" "+(path || "");
        werror("[HTTP_API][SLOW] %s %s took %d ms\n",
            method || "",path || "",elapsed_ms);
    }
}

mapping query_http_performance_status()
{
    return ([
        "request_count":http_request_count,
        "slow_request_count":http_slow_request_count,
        "slow_threshold_ms":HTTP_SLOW_REQUEST_MS,
        "max_request_ms":http_max_request_ms,
        "last_slow_time":http_last_slow_time,
        "last_slow_path":http_last_slow_path,
    ]);
}

void handle_request(Protocols.HTTP.Server.Request req)
{
    string path = req->not_query;
    string method = req->request_type;
    int request_started_at = gethrtime();
    string map_worker_request_id = "";

    // http_werror(" %s %s from %s\n", method, path, req->remote_addr || "unknown");

    if((req->query && sizeof(req->query)>MAX_HTTP_QUERY_SIZE) ||
       (req->body_raw && sizeof(req->body_raw)>MAX_HTTP_BODY_SIZE) ||
       (path && sizeof(path)>MAX_HTTP_QUERY_SIZE)){
        send_json(req,(["error":"Request too large"]),413);
        record_http_request_timing(method,path,request_started_at);
        return;
    }

    if(path!="/internal/map-worker" &&
       !map_worker_gateway_request_authorized(req)){
        send_json(req,(["error":"worker gateway authorization required"]),403);
        record_http_request_timing(method,path,request_started_at);
        return;
    }

    if(path!="/internal/map-worker" &&
       MAP_WORKERD->query_node_role()=="worker"){
        map_worker_request_id = lower_case(String.trim_all_whites(
            req->request_headers["x-xiand-request-id"] || ""));
        mapping request_begin = MAP_WORKERD->begin_local_gateway_request(
            map_worker_request_id,
            String.trim_all_whites(
                req->request_headers["x-xiand-lease-userid"] || ""),
            (int)(req->request_headers["x-xiand-lease-epoch"] || "0"),
            lower_case(String.trim_all_whites(
                req->request_headers["x-xiand-command-kind"] || "general")),
            String.trim_all_whites(
                req->request_headers["x-xiand-admin-target-userid"] || ""),
            String.trim_all_whites(
                req->request_headers["x-xiand-admin-target-account"] || ""),
            lower_case(String.trim_all_whites(
                req->request_headers["x-xiand-admin-target-worker"] || "")),
            (int)(req->request_headers["x-xiand-admin-target-epoch"] || "0"),
            (int)(req->request_headers["x-xiand-admin-fee"] || "0"),
            lower_case(String.trim_all_whites(
                req->request_headers["x-xiand-admin-recharge-request"] || "")),
            String.trim_all_whites(
                req->request_headers["x-xiand-admin-item-path"] || ""),
            (int)(req->request_headers["x-xiand-admin-item-count"] || "0"),
            lower_case(String.trim_all_whites(
                req->request_headers["x-xiand-admin-item-request"] || "")),
            lower_case(String.trim_all_whites(
                req->request_headers["x-xiand-admin-capability"] || "")),
            String.trim_all_whites(
                req->request_headers["x-xiand-account-owner"] || ""));
        if(!(int)request_begin["ok"]){
            send_json(req,(["error":"worker request fence rejected",
                "code":request_begin["code"]]),409);
            record_http_request_timing(method,path,request_started_at);
            return;
        }
    }

    // CORS 预检不进入异常捕获块，遵守 Pike catch 内不提前 return 的约束。
    if(method == "OPTIONS") {
        send_cors(req);
        record_http_request_timing(method,path,request_started_at);
        return;
    }

    mixed err = catch {
        // API路由分发
        switch(path) {
            case "/internal/map-worker":
                handle_map_worker_rpc(req);
                break;
            case "/api":
                handle_api(req);
                break;
            case "/api/partitions":
                handle_api_partitions(req);
                break;
            case "/api/challenge":
                handle_api_challenge(req);
                break;
            case "/api/account/login":
                handle_api_account_login(req);
                break;
            case "/api/account/characters":
                handle_api_account_characters(req);
                break;
            case "/api/account/illusion/activate":
                handle_api_account_illusion_activate(req);
                break;
            case "/api/account/illusion/expand":
                handle_api_account_illusion_expand(req);
                break;
            case "/api/account/characters/create":
                handle_api_account_character_create(req);
                break;
            case "/api/account/characters/select":
                handle_api_account_character_select(req);
                break;
            case "/api/account/bookmark/create":
                handle_api_account_bookmark_create(req);
                break;
            case "/api/account/bookmark/open":
                handle_api_account_bookmark_open(req);
                break;
            case "/api/account/bookmark/revoke":
                handle_api_account_bookmark_revoke(req);
                break;
            case "/api/profile":
                handle_api_character_profile(req);
                break;
            case "/api/account/logout":
                handle_api_account_logout(req);
                break;
            case "/api/status":
                handle_api_status(req);
                break;
            case "/api/ping":
                handle_api_ping(req);
                break;
            case "/api/equipment_panel":
                handle_api_equipment_panel(req);
                break;
            case "/api/autofight":
                handle_api_autofight(req);
                break;
            case "/api/autofight_view":
                handle_api_autofight_view(req);
                break;
            case "/api/async":
                handle_api_async(req);
                break;
            case "/api/result":
                handle_api_result(req);
                break;
            case "/api/chat/messages":
                handle_api_chat_messages(req);
                break;
            case "/api/chat/send":
                handle_api_chat_send(req);
                break;
            case "/exits":
                handle_exits(req);
                break;
            case "/room":
                handle_room(req);
                break;
            case "/health":
                mapping m = ([
                    "status":"ok",
                    "time":time(),
                ]);
                string configured_health_token =
                    getenv("XIAND_HEALTH_TOKEN") || "";
                string supplied_health_token =
                    req->request_headers["x-xiand-health-token"] || "";
                int detailed_health = sizeof(configured_health_token)>=24 &&
                    supplied_health_token==configured_health_token;
                if(detailed_health){
                    mapping queue_status = query_queue_status();
                    mapping thread_status = query_thread_status();
                    string health_node_role = MAP_WORKERD->query_node_role();
                    m["port"] = http_listen_port;
                    m["uptime"] = http_api_start_time > 0 ?
                        time()-http_api_start_time : 0;
                    m["queue"] = ([
                        "active_queues":queue_status["active_queues"] || 0,
                        "processing":queue_status["processing"] || 0,
                        "cached_results":queue_status["cached_results"] || 0,
                        "dispatch_mode":queue_status["dispatch_mode"] || "unknown",
                    ]);
                    m["threads"] = thread_status;
                    m["async_io"] = ASYNC_IOD->query_status();
                    m["runtime"] = query_runtime_performance();
                    // The coordinator owns routing only. Loading gameplay
                    // daemons merely to serve monitoring previously blocked
                    // its public gateway for several seconds after startup.
                    if(health_node_role!="gateway"){
                        m["config_caches"] = ([
                            "map":MAPD->query_cache_status(),
                            "task":TASKD->query_cache_status(),
                            "skill":MUD_SKILLSD->query_cache_status(),
                            "autofight":AUTOFIGHTD->
                                query_training_route_cache_status(),
                        ]);
                        m["autofight_performance"] = AUTOFIGHTD->
                            query_autofight_performance_status();
                    }
                    else{
                        m["config_caches"] = ([
                            "mode":"not_collected_on_gateway",
                        ]);
                        m["autofight_performance"] = ([
                            "mode":"not_collected_on_gateway",
                        ]);
                    }
                    m["performance"] = query_http_performance_status();
                    m["account_sessions"] = query_account_session_status();
                    m["command_tokens"] = query_hidden_command_status();
                    m["pagination"] = query_pagination_status();
                    m["map_workers"] = MAP_WORKERD->query_status();
                }
                if(!send_json_mapping_async(req,m,200))
                    send_json(req,m);
                break;
            case "/":
                if(api_only_mode) {
                    mapping info = ([ "message": "HTTP API Server", "api": "/api", "health": "/health" ]);
                    send_json(req, info);
                } else {
                    serve_file(req, "web/web_vue/index.html", "text/html");
                }
                break;
            default:
                // 处理 /api/html?xxx 格式
                if(search(path, "/api/html") == 0) {
                    handle_api_html(req);
                }
                // 处理 /api/json?xxx 格式 - 返回JSON供Vue前端解析
                else if(search(path, "/api/json") == 0) {
                    handle_api_json(req);
                }
                // 处理 /api/battle_status?xxx 格式 - 获取战斗状态（敌我双方）
                else if(search(path, "/api/battle_status") == 0) {
                    handle_api_battle_status(req);
                }
                // 处理 /api/performs?xxx 格式 - 获取可用招式列表
                else if(search(path, "/api/performs") == 0) {
                    handle_api_performs(req);
                }
                // 处理 /api/invite/seturl 格式 - 设置邀请URL
                else if(path == "/api/invite/seturl") {
                    handle_api_invite_seturl(req);
                }
                // translate.js 从 http_api 目录提供（始终允许，不受api_only_mode限制）
                else if(path == "/includes/translate.js") {
                    serve_file(req, "gamelib/single/daemons/_http_api_mod/translate.js", "application/javascript");
                }
                // 静态资源
                else if(search(path, "/css/") == 0 || search(path, "/js/") == 0) {
                    if(!api_only_mode) {
                        serve_file(req, "web/web_vue" + path, guess_type(path));
                    } else {
                        send_json(req, ([ "error": "API only mode" ]), 404);
                    }
                }
                // images 目录在 web/ 下
                else if(search(path, "/images/") == 0) {
                    if(!api_only_mode) {
                        serve_file(req, "web" + path, guess_type(path));
                    } else {
                        send_json(req, ([ "error": "API only mode" ]), 404);
                    }
                }
                else {
                    send_json(req, ([ "error": "Not found" ]), 404);
                }
                break;
        }
    };

    if(err) {
        http_werror(" Request error: %s\n", describe_error(err));
        // 检查对象是否已被析构，避免再次调用函数导致错误
        if(objectp(req)) {
            mixed send_err = catch {
                send_json(req, ([ "error": "Internal error" ]), 500);
            };
            if(send_err) {
                http_werror(" Failed to send error response: %s\n", describe_error(send_err));
            }
        }
    }
    record_http_request_timing(method,path,request_started_at);
}

// ========================================================================
// API处理函数
// ========================================================================

void handle_api(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);
    string userid = params["userid"];
    string password = params["password"];
    string cmd = params["cmd"];
    if(!cmd || cmd == "") cmd = "look";

    string auth_userid, auth_password;
    string stored_password;
    string challenge = params["challenge"];

    if(txd && txd != "" && txd != " ") {
        mapping auth = decode_txd(txd);
        if(!auth) {
            send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
            return;
        }
        auth_userid = String.trim_all_whites(auth["userid"]);
        auth_password = auth["password"];

        // TXD 也需要验证密码
        stored_password = get_user_password(auth_userid);
        if(!stored_password) {
            send_json(req, ([ "error": "用户不存在" ]), 401);
            return;
        }
        if(!character_login_password_matches(auth_userid,stored_password,
           auth_password,"")) {
            send_json(req, ([ "error": "用户名或密码错误" ]), 401);
            return;
        }
        auth_password = stored_password;
    }
    else if(userid && password && userid != "" && password != "") {
        auth_userid = String.trim_all_whites(userid);

        // 密码验证
        stored_password = get_user_password(auth_userid);
        if(!stored_password) {
            send_json(req, ([ "error": "用户不存在" ]), 401);
            return;
        }
        if(!character_login_password_matches(auth_userid,stored_password,
           password,challenge || "")) {
            send_json(req, ([ "error": "用户名或密码错误" ]), 401);
            return;
        }
        auth_password = stored_password;
    }
    else {
        send_json(req, ([ "error": "缺少认证信息" ]), 400);
        return;
    }

    if(!execute_command_async(auth_userid,auth_password,cmd,
       finish_handle_api,req,auth_userid))
        send_json(req,(["error":"命令队列繁忙，请稍后重试"]),503);
}

void finish_handle_api(string response,
    Protocols.HTTP.Server.Request req,string auth_userid)
{

    if(!response) {
        send_json(req, ([ "error": "命令执行失败" ]), 500);
        return;
    }

    if(search(response, "登录错误") != -1 || search(response, "用户名不存在") != -1) {
        send_json(req, ([ "error": "用户名或密码错误" ]), 401);
        return;
    }

    mapping result = parse_response_to_json(response, auth_userid);
    send_json(req, result);
}

void handle_api_html(Protocols.HTTP.Server.Request req)
{
    http_werror("========== handle_api_html called! ==========\n");
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);
    string userid = params["userid"];
    string password = params["password"];
    string cmd = params["cmd"];
    // 历史人物ID区分大小写；邀请码必须保留分享人的精确ID，不能像
    // 新注册短账号一样规范化成小写，否则 LSQ 会错误归到 lsq。
    string ref_code = String.trim_all_whites(
        url_decode((string)(params["ref"] || "")));
    http_werror(" handle_api_html request received\n");
    if(!cmd || cmd == "") cmd = "look";

    string client_ip = normalize_http_client_ip(
        req->remote_addr || "unknown");

    // 注册命令处理 - 直接实现注册逻辑（xiand没有login_regnew命令）
    if(search(cmd, "login_regnew ") == 0) {
        http_werror("=== REGISTER REQUEST ===\n");
		// 注册命令包含明文密码，禁止写入任何运行日志。

        if(check_register_rate_limit(client_ip)) {
            http_werror(" RATE LIMIT EXCEEDED for IP: %s\n", client_ip);
            send_html_error(req, "注册尝试过于频繁，请稍后再试");
            return;
        }

        // Vue sends six tokens including the command. Old JSP sends at least
        // nine, with the logical-zone prefix separate from the short name.
        string projname = "", user_name = "", pswd = "", sid = "";
        string game_pre = "", m_key = "", userip = "", userua = "";
        string challenge = "";
        array(string) registration_fields = cmd/" ";
        registration_fields -= ({""});
        int parse_result = 0;
        if(sizeof(registration_fields)==6 &&
           registration_fields[0]=="login_regnew") {
            projname = registration_fields[1];
            user_name = registration_fields[2];
            pswd = registration_fields[3];
            sid = registration_fields[4];
            challenge = registration_fields[5];
            parse_result = 5;
        }
	        else if(sizeof(registration_fields)>=9 &&
	                registration_fields[0]=="login_regnew") {
            projname = registration_fields[1];
            user_name = registration_fields[2];
            pswd = registration_fields[3];
            sid = registration_fields[4];
            game_pre = registration_fields[5];
            m_key = registration_fields[6];
            userip = registration_fields[7];
            userua = registration_fields[8..]*" ";
	            parse_result = 8;
	        }
	        // 人物/账号档案文件名严格区分大小写。只规范逻辑区前缀，
	        // 绝不能把账号主体转成小写，否则 LSQ 与 lsq 会注册、邀请
	        // 和返利到同一身份。
	        user_name = String.trim_all_whites(user_name || "");
	        game_pre = lower_case(String.trim_all_whites(game_pre || ""));

        http_werror(" registration fields parsed: count=%d, password_len=%d\n",
                    parse_result,sizeof(pswd));

        if(parse_result >= 3) {
            // 解析用户名和分区前缀
            // Vue发送: tx01jinghaha152 (已含前缀), JSP发送: jinghaha152 (不含前缀，game_pre单独传)
            string game_fg = game_pre || "";  // 分区前缀如 xd01, tx01
            string actual_user = user_name;   // 实际用户名（不含前缀）

            // 如果user_name包含分区前缀(字母+2位数字)，提取出来
            string prefix = "";
            int num = 0;
            string rest = "";
            if(sscanf(user_name, "%[a-zA-Z]%d%s", prefix, num, rest) == 3 && sizeof(prefix) == 2 && num >= 1 && num <= 99) {
                // user_name包含前缀，如 tx01jinghaha152
                if(game_fg == "") {
                    game_fg = lower_case(prefix) + sprintf("%02d", num);
                }
                actual_user = rest;  // 实际用户名是去掉前缀的部分
            }

            http_werror(" Parsed: game_fg=%s, user_name=%s (len=%d), actual_user=%s (len=%d), password_len=%d\n",
                        game_fg, user_name, sizeof(user_name), actual_user, sizeof(actual_user), sizeof(pswd));

            // 构建完整用户名（含分区前缀）用于存储
            string full_username = game_fg + actual_user;
            http_werror(" Full username for storage: %s\n", full_username);

            // HTTP API 模式下直接实现注册逻辑
            // 注意：存储明文密码，登录时用challenge做哈希验证
            string result;
            string error_msg = "";  // 详细错误信息

            // 验证实际用户名长度（不含分区前缀）
            if(projname!="gamelib") {
                http_werror(" VALIDATION FAILED: invalid project\n");
                result = "error2";
                error_msg = "注册入口无效";
            } else if(!LOGICALZONED->registration_allowed(game_fg)) {
                http_werror(" VALIDATION FAILED: logical zone is not open: %s\n",game_fg);
                result = "error2";
                error_msg = "该区尚未开放注册或正在维护";
            } else if(sizeof(actual_user) < 2) {
                http_werror(" VALIDATION FAILED: actual_user_len=%d (need >=2)\n", sizeof(actual_user));
                result = "error2";
                error_msg = "用户名过短，最少2个字符";
            } else if(sizeof(actual_user) > 12) {
                http_werror(" VALIDATION FAILED: actual_user_len=%d (need <=12)\n", sizeof(actual_user));
                result = "error2";
                error_msg = "用户名过长，最多12个字符（当前" + sizeof(actual_user) + "个）";
            } else if(sizeof(pswd) < 2) {
                http_werror(" VALIDATION FAILED: password_len=%d (need >=2)\n", sizeof(pswd));
                result = "error2";
                error_msg = "密码过短，最少2个字符";
            } else {
                // 检查用户名只包含字母数字（检查实际用户名，不含前缀）
                int valid_name = 1;
                for(int i = 0; i < sizeof(actual_user); i++) {
                    int c = actual_user[i];
                    if(!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9'))) {
                        http_werror(" INVALID CHAR at position %d: %c (%d)\n", i, c, c);
                        valid_name = 0;
                        break;
                    }
                }
                mapping referral_precheck=(["ok":1]);
                if(valid_name && ref_code!="")
					referral_precheck=REFERRALD->validate_registration_invite(
						full_username,ref_code,client_ip);
                if(!valid_name) {
                    http_werror(" VALIDATION FAILED: invalid characters in actual_user\n");
                    result = "error2";
                    error_msg = "用户名只能包含字母和数字";
                } else if(!(int)referral_precheck["ok"]) {
					http_werror(" REFERRAL VALIDATION FAILED: code=%s\n",
						(string)(referral_precheck["code"] || "unknown"));
					result="error2";
					error_msg=(string)(referral_precheck["message"] ||
						"邀请码无效");
                } else {
                    // full_username已在上面定义: game_fg + actual_user
                    // 与登录、原子存档统一使用 data_xiand，严禁覆盖已有旧人物。
                    string user_file_path = DATA_ROOT + "u/" +
                        full_username[sizeof(full_username)-2..] + "/" +
                        full_username + ".o";
                    http_werror(" Checking user file: %s\n", user_file_path);
                    string existing_user =
                        ASYNC_IOD->read_text(user_file_path,1024*1024);

                    if(existing_user) {
                        // 用户已存在
                        http_werror(" User already exists: %s\n", full_username);
                        result = "error1";
                        error_msg = "用户名已存在";
                    } else {
                        // 检查内存中是否有在线用户
                        http_werror(" Checking if user in memory...\n");
                        object user_in_memory = find_player(full_username);
                        if(user_in_memory) {
                            http_werror(" User already in memory: %s\n", full_username);
                            result = "error1";
                            error_msg = "用户已在线";
                        } else {
                            // 创建新用户 - 直接创建用户文件
                            http_werror(" Creating new user...\n");
                            http_werror(" ROOT=%s\n", ROOT);

                            program u;
                            object m;

                            // 尝试加载 master.pike（如果失败则忽略）
                            http_werror(" Step 1: Loading master.pike...\n");
                            mixed master_err = catch {
                                m = (object)(ROOT + "/gamelib/master.pike");
                                http_werror(" master.pike loaded: %O\n", m);
                                if(m) http_werror(" master.pike functions: %O\n", indices(m));
                            };
                            if(master_err) {
                                http_werror(" master.pike load ERROR: %s\n", describe_error(master_err));
                            }

                            http_werror(" Step 2: Getting user program...\n");
                            if(m && functionp(m->connect)) {
                                http_werror(" Found master->connect function\n");
                                u = m->connect();
                                http_werror(" Using master.pike->connect(): %O\n", u);
                            }
                            if(!u) {
                                http_werror(" No master->connect, loading user.pike directly...\n");
                                mixed user_prog_err = catch {
                                    u = (program)(ROOT + "/gamelib/clone/user.pike");
                                    http_werror(" Using user.pike: %O\n", u);
                                };
                                if(user_prog_err) {
                                    http_werror(" user.pike load ERROR: %s\n", describe_error(user_prog_err));
                                }
                            }

                            if(!u) {
                                http_werror(" FATAL: Cannot load user program!\n");
                                result = "error2";
                                error_msg = "系统错误: 无法加载用户程序";
                            } else {
                                http_werror(" Step 3: Creating user instance...\n");
                                mixed err = catch {
                                    object me = u();
                                    http_werror(" user object created: %O\n", me);
                                    if(!me) {
                                        http_werror(" FATAL: u() returned NULL!\n");
                                        result = "error2";
                                        error_msg = "系统错误: 无法创建用户对象";
                                    } else {
                                        http_werror(" Step 4: Setting user properties...\n");

                                        http_werror("  Calling set_name(%s)...\n", full_username);
                                        me->set_name(full_username);

                                        http_werror("  Calling set_password()...\n");
                                        me->set_password(pswd);

                                        http_werror("  Calling set_project(%s)...\n", projname || "gamelib");
                                        me->set_project(projname || "gamelib");

                                        http_werror("  Calling set_userip(%s)...\n", client_ip);
                                        me->set_userip(client_ip);

                                        // 初始化必要字段，避免 query_desc() 出错
                                        http_werror("  Initializing basic fields...\n");
                                        if(!me->sid) {
                                            me->sid = sid || "tmpUser";
                                        }

                                        http_werror(" Step 5: Calling setup()...\n");
                                        mixed setup_err = catch {
                                            if(me->setup(pswd)) {
                                                // 注册成功
                                                http_werror("  setup() returned SUCCESS\n");
                                                if(environment(me) == 0) {
                                                    http_werror("  Moving to LOW_VOID_OB...\n");
                                                    me->move(LOW_VOID_OB);
                                                }

                                                // The gateway registration lock is the creation
                                                // fence. Persist atomically before reporting success.
                                                http_werror("  Saving user file...\n");
                                                int registration_saved =
                                                    functionp(me->save_with_result) &&
                                                    me->save_with_result(0,
                                                        MAP_WORKERD->query_node_role()=="worker" ? 1 : 0);
                                                if(registration_saved) {
                                                    http_werror("  User file saved successfully\n");
													mapping referral_binding=(["ok":1]);
                                                    if(ref_code!="") {
													referral_binding=REFERRALD->bind_registration(
                                                                full_username,ref_code,
                                                                client_ip);
                                                    }
													if(!(int)referral_binding["ok"]){
														http_werror(" Referral binding failed after save: code=%s\n",
															(string)(referral_binding["code"] || "unknown"));
														rm(user_file_path);
												rm(user_file_path+".tmp");
												rm(user_file_path+".bak");
												rm(user_file_path+".bak.tmp");
														result="error2";
														error_msg=(string)(referral_binding["message"] ||
															"邀请关系安全保存失败，请重试");
													}
													else{
														http_werror(" Registration SUCCESS: %s\n", full_username);
														result = actual_user + "," + pswd;
													}
                                                }
                                                else {
                                                    http_werror("  User file save FAILED\n");
                                                    result = "error2";
                                                    error_msg = "用户档案写入失败，请重试";
                                                }
                                            } else {
                                                http_werror("  setup() returned FALSE\n");
                                                result = "error2";
                                                error_msg = "用户初始化失败";
                                            }
                                        };
                                        if(setup_err) {
                                            http_werror("  setup() EXCEPTION: %s\n", describe_error(setup_err));
                                            result = "error2";
                                            error_msg = "用户初始化异常: " + describe_error(setup_err);
                                        }
                                        // Registration is not a logged-in player lease. Keep only
                                        // the canonical archive and remove this temporary object.
                                        if(me) {
                                            if(functionp(me->discard_stale_worker_copy))
                                                me->discard_stale_worker_copy();
                                            else
                                                destruct(me);
                                        }
                                    }
                                };
                                if(err) {
                                    http_werror(" User creation EXCEPTION: %s\n", describe_error(err));
                                    result = "error2";
                                    error_msg = "创建用户异常: " + describe_error(err);
                                }
                            }
                        }
                    }
                }
            }

            http_werror(" Registration completed: success=%d error=%s\n",
                search(result || "","error")!=0,error_msg || "");

            // 返回注册结果 - 格式: result 或 result,error_msg
            string response_data = result;
            if(error_msg && sizeof(error_msg) > 0) {
                response_data = result + "," + error_msg;
            }
            string html = "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><title>注册</title></head><body><div>" + response_data + "</div></body></html>";
            mapping resp = ([ ]);
            resp["type"] = "text/html; charset=UTF-8";
            resp["data"] = html;
            resp["error"] = 200;
            resp["extra_heads"] = (["cache-control": "no-cache", "Access-Control-Allow-Origin": "*"]);
            finish_http_response(req,resp);
            return;
        }

        // 参数格式错误或加载失败
        http_werror(" Registration FAILED: invalid parameters (sscanf returned %d, need >=3)\n", parse_result);
        send_html_error(req, "error2");
        return;
    }

    // 认证
    string auth_userid, auth_password;
    string stored_password, authenticated_txd;
    string challenge = params["challenge"];

    if(txd && txd != "" && txd != " ") {
        mapping auth = decode_txd(txd);
        if(!auth) {
            send_html_error(req, "TXD认证信息无效");
            return;
        }
        auth_userid = String.trim_all_whites(auth["userid"]);
        auth_password = auth["password"];

        // TXD 也需要验证密码
        stored_password = get_user_password(auth_userid);
        if(!stored_password) {
            send_html_error(req, "用户不存在");
            return;
        }
        if(!character_login_password_matches(auth_userid,stored_password,
           auth_password,"")) {
            send_html_error(req, "用户名或密码错误");
            return;
        }
        auth_password = stored_password;
    }
    else if(userid && password && userid != "" && password != "") {
        auth_userid = String.trim_all_whites(userid);

        // 密码验证
        stored_password = get_user_password(auth_userid);
        if(!stored_password) {
            send_html_error(req, "用户不存在");
            return;
        }
        if(!character_login_password_matches(auth_userid,stored_password,
           password,challenge || "")) {
            send_html_error(req, "用户名或密码错误");
            return;
        }
        auth_password = stored_password;
    }
    else {
        send_html_error(req, "缺少认证信息");
        return;
    }

    // 已有书签通过严格认证后原样沿用，禁止改变玩家保存的 TXD；仅首次使用
    // 用户名密码登录时按历史算法生成完整 token。challenge 登录也必须使用
    // 档案中的真实密码，而不是请求中的哈希。
    if(txd && txd!="" && txd!=" ")
        authenticated_txd = txd;
    else
        authenticated_txd = generate_txd(auth_userid,stored_password);

    // 登录速率限制
    int is_login_attempt = (!txd || txd == "" || txd == " ");
    if(is_login_attempt) {
        if(check_login_rate_limit(client_ip)) {
            send_html_error(req, "登录尝试过于频繁，请稍后再试");
            return;
        }
    }

    // 解码不可变命令令牌；输入框后缀由 unhide_command 统一拼接。
    cmd = unhide_command(auth_userid, cmd);

    // 滚动部署期间旧页面仍会每秒提交 flushview。服务端调度已开启时
    // 直接复用最近画面，避免同一人物被新旧调度各推进一次。
    if(query_command_name(cmd)=="flushview"){
        object cached_player = get_player_from_connection(auth_userid,0);
        if(cached_player &&
           AUTOFIGHTD->query_server_autofight_tick_active(cached_player)){
            mapping cached_view =
                AUTOFIGHTD->query_server_autofight_view(cached_player);
            string cached_output = (string)cached_view["output"];
            if(cached_output!=""){
                finish_handle_api_html(cached_output,req,auth_userid,cmd,
                    authenticated_txd,client_ip,is_login_attempt);
                return;
            }
        }
    }

    if(!execute_command_async(auth_userid,auth_password,cmd,
       finish_handle_api_html,req,auth_userid,cmd,authenticated_txd,
       client_ip,is_login_attempt))
        send_html_error(req,"命令队列繁忙，请稍后重试");
}

void finish_handle_api_html(string response,
    Protocols.HTTP.Server.Request req,string auth_userid,string cmd,
    string authenticated_txd,string client_ip,int is_login_attempt)
{

    if(!response) {
        if(is_login_attempt) record_login_failure(client_ip);
        send_html_error(req, "命令执行失败");
        return;
    }

    int login_success = 0, login_failed = 0;
    if(is_login_attempt) {
        if(search(response, "登录错误") != -1 || search(response, "用户名不存在") != -1) {
            login_failed = 1;
        } else if(search(response, "error") == -1 && sizeof(response) > 10) {
            login_success = 1;
        }
    }

    if(login_failed) {
        record_login_failure(client_ip);
    } else if(login_success) {
        reset_login_failures(client_ip);
    }

    string html = response_to_html(response,auth_userid,cmd,
        authenticated_txd);

    mapping resp = ([ ]);
    resp["type"] = "text/html; charset=UTF-8";
    resp["data"] = html;
    resp["error"] = 200;
    resp["extra_heads"] = (["cache-control": "no-cache", "Access-Control-Allow-Origin": "*"]);
    mixed response_err = catch {
        finish_http_response(req,resp);
    };
    if(response_err)
        http_werror(" async HTML response error: %s\n",
            describe_error(response_err));
}

// ========================================================================
// JSON API - 返回解析后的结构化数据供Vue前端渲染
// ========================================================================

void handle_api_json(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);
    string userid = params["userid"];
    string password = params["password"];
    string cmd = params["cmd"];
    if(!cmd || cmd == "") cmd = "look";

    string client_ip = req->remote_addr || "unknown";

    // 认证
    string auth_userid, auth_password;
    string stored_password;
    string challenge = params["challenge"];

    if(txd && txd != "" && txd != " ") {
        mapping auth = decode_txd(txd);
        if(!auth) {
            send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
            return;
        }
        auth_userid = String.trim_all_whites(auth["userid"]);
        auth_password = auth["password"];

        // TXD 也需要验证密码
        stored_password = get_user_password(auth_userid);
        if(!stored_password) {
            send_json(req, ([ "error": "用户不存在" ]), 401);
            return;
        }
        if(!character_login_password_matches(auth_userid,stored_password,
           auth_password,"")) {
            send_json(req, ([ "error": "用户名或密码错误" ]), 401);
            return;
        }
        auth_password = stored_password;
    }
    else if(userid && password && userid != "" && password != "") {
        auth_userid = String.trim_all_whites(userid);

        // 密码验证
        stored_password = get_user_password(auth_userid);
        if(!stored_password) {
            send_json(req, ([ "error": "用户不存在" ]), 401);
            return;
        }
        if(!character_login_password_matches(auth_userid,stored_password,
           password,challenge || "")) {
            send_json(req, ([ "error": "用户名或密码错误" ]), 401);
            return;
        }
        auth_password = stored_password;
    }
    else {
        send_json(req, ([ "error": "缺少认证信息" ]), 400);
        return;
    }

    // 达到同账号在线上限后，旧标签页仍会携带缓存TXD持续flushview。
    // 明确返回409，禁止它自动重登并反过来清退另一个正在玩的职业。
    mapping forced_logout = ACCOUNT_CHARACTERD->
        query_recent_forced_logout(auth_userid);
    if((int)forced_logout["forced_logout"]){
        send_json(req,forced_logout,409);
        return;
    }

    // 解码隐藏命令（cmd可能是数字索引）
    string actual_cmd = unhide_command(auth_userid, cmd);

    // 兼容仍在运行的旧前端：服务端挂机已接管后，旧 flushview 请求
    // 只读取最近画面，不能再次推进战斗。
    if(query_command_name(actual_cmd)=="flushview"){
        object cached_player = get_player_from_connection(auth_userid,0);
        if(cached_player &&
           AUTOFIGHTD->query_server_autofight_tick_active(cached_player)){
            mapping cached_view =
                AUTOFIGHTD->query_server_autofight_view(cached_player);
            string cached_output = (string)cached_view["output"];
            if(cached_output!=""){
                finish_handle_api_json(cached_output,req,auth_userid,
                    auth_password,cmd);
                return;
            }
        }
    }

    // 所有人物命令进入公平Backend队列；完成后并行解析纯响应。
    if(!execute_command_async(auth_userid,auth_password,actual_cmd,
       finish_handle_api_json,req,auth_userid,auth_password,cmd))
        send_json(req,(["error":"命令队列繁忙，请稍后重试"]),503);
}

string query_visual_room_id(object|zero player)
{
    object|zero room;
    string room_path;
    string marker = "/gamelib/d/";
    int marker_pos;
    int clone_pos;
    if(!player)
        return "";
    room = environment(player);
    if(!room)
        return "";
    // file_name() is the canonical room path used by the Worker handoff code.
    // object_name() may describe the runtime object instead of its source file,
    // which made otherwise valid Worker rooms fail the /gamelib/d/ check.
    room_path = file_name(room) || "";
    marker_pos = search(room_path,marker);
    if(marker_pos==-1)
        return "";
    room_path = room_path[marker_pos+sizeof(marker)..];
    clone_pos = search(room_path,"#");
    if(clone_pos!=-1)
        room_path = room_path[..clone_pos-1];
    if(has_suffix(room_path,".pike"))
        room_path = room_path[..sizeof(room_path)-6];
    if(room_path=="" || search(room_path,"..")!=-1 ||
       search(room_path,":")!=-1)
        return "";
    return room_path;
}

string build_command_json_response_job(string response,string new_txd,
    string auth_userid,string cmd,array(mapping) newbie_completions,
    mapping refresh_snapshot,string room_id)
{
    array(mapping) lines = parse_mud_to_json(response, new_txd, auth_userid);
    string copy_data;
    string copy_type;
    if(search(response, "COPY_CODE:") != -1) {
        sscanf(response, "%*sCOPY_CODE:%[^[ \n\r]", copy_data);
        copy_type = "code";
        lines = filter(lines, lambda(mapping m) {
            string text = get_line_text(m);
            return search(text, "COPY_CODE:") == -1;
        });
    } else if(search(response, "COPY_LINK:") != -1) {
        // 提取复制数据 - 只提取到行尾或UI按钮前
        sscanf(response, "%*sCOPY_LINK:%[^[ \n\r]", copy_data);
        copy_type = "link";
        lines = filter(lines, lambda(mapping m) {
            string text = get_line_text(m);
            return search(text, "COPY_LINK:") == -1;
        });
    }

    mapping json_result = ([
        "lines": lines,
        "userid": auth_userid,
        "cmd": cmd,
        "txd": new_txd,
        "timestamp": time()
    ]);

    if(copy_data && sizeof(copy_data) > 0 && copy_type) {
        json_result->copy = (["type":copy_type, "data":copy_data]);
    }
    if(sizeof(newbie_completions) > 0) {
        json_result->newbie_completions = newbie_completions;
    }
    if(mappingp(refresh_snapshot) && sizeof(refresh_snapshot)>0)
        json_result->refresh = refresh_snapshot;
    if(room_id!="")
        json_result->room_id = room_id;
    return Standards.JSON.encode(json_result);
}

void finish_handle_api_json(string response,
    Protocols.HTTP.Server.Request req,string auth_userid,
    string auth_password,string cmd)
{
    string command_response;
    object response_player = get_player_from_connection(auth_userid);
    array(mapping) newbie_completions = ({});
    mapping refresh_snapshot = ([]);
    string stored_password;
    string new_txd;
    string room_id = "";

    command_response = String.trim_all_whites(response || "");
    // Worker 内部转发请求不一定持有原始 HTTP 虚拟连接，但人物对象仍在
    // 当前 Worker。用全局在线对象兜底，确保精确房间 ID 不会在网关链路中
    // 因连接归属不同而丢失；这里只读取 environment，不改变人物状态。
    if(!response_player)
        response_player = find_player(auth_userid);
    // 调度/运行时异常不能伪装成普通MUD文字。返回HTTP错误后，选角页会
    // 保留已创建人物并允许重试，而不是带着半初始化界面进入游戏。
    if(has_prefix(command_response,"错误:") ||
       command_response=="命令执行错误" ||
       has_prefix(command_response,"{\"error\":")){
        send_json(req,(["error":"游戏命令执行失败，请重试；若持续出现请联系管理员。"]),500);
        return;
    }
    if(response_player) {
        room_id = query_visual_room_id(response_player);
        newbie_completions =
            NEWBIED->consume_completion_notices(response_player);
        if(query_command_name(cmd)=="flushview")
            refresh_snapshot = query_autofight_refresh_snapshot(
                response_player);
    }

    // TXD 格式与生成逻辑保持不变；只把纯文本解析和JSON编码放到线程池。
    stored_password = get_user_password(auth_userid);
    new_txd = generate_txd(auth_userid,stored_password || auth_password);

    if(!send_json_builder_async(req,build_command_json_response_job,({
        response,new_txd,auth_userid,cmd,newbie_completions,
        refresh_snapshot,room_id
    }),200))
        send_json(req,(["error":"响应线程池繁忙，请稍后重试"]),503);
}

/**
 * 获取行的完整文本内容
 */
string get_line_text(mapping m)
{
    if(!m["segments"]) return "";

    string text = "";
    array segments = m["segments"];
    foreach(segments, mixed seg) {
        if(seg["type"] == "text") {
            if(seg["parts"]) {
                foreach(seg["parts"], mixed p) {
                    if(p["content"]) text += p["content"];
                }
            }
        } else if(seg["type"] == "button") {
            text += seg["label"] || "";
        }
    }
    return text;
}

/**
 * 解析MUD输出为结构化JSON数组
 * 每行是一个对象，包含type和content
 * 支持跨行表单：连续的 [string name:...] 输入框后跟 [submit label:cmd ...]
 */
array(mapping) parse_mud_to_json(string response, string txd, string userid)
{
    array(mapping) result = ({});

    if(!response) return result;

    array raw_lines = response / "\n";

    // 跨行表单状态追踪
    array(mapping) form_inputs = ({});     // 积累的输入框
    array(int) form_line_indices = ({});   // 包含输入框的行索引
    int in_form = 0;

    foreach(raw_lines, string line) {
        string original_line = line;
        line = String.trim_all_whites(line);

        // 去掉行尾的{数字}标记
        while(1) {
            int start = search(line, "{");
            if(start == -1) break;
            int end = search(line, "}", start);
            if(end == -1) break;
            string between = line[start+1..end-1];
            int is_all_digits = 1;
            for(int i = 0; i < sizeof(between); i++) {
                if(between[i] < '0' || between[i] > '9') {
                    is_all_digits = 0;
                    break;
                }
            }
            if(is_all_digits) {
                line = line[0..start-1] + line[end+1..];
            } else {
                break;
            }
        }

        if(!sizeof(line)) {
            result += ({(["type": "empty"])});
            continue;
        }

        // 先扫描行中是否有输入框或submit按钮
        int has_input = 0;
        int has_submit = 0;
        array(mapping) raw_segments = ({});

        int current = 0;
        while(current < sizeof(line)) {
            int start = search(line, "[", current);
            if(start == -1) break;
            int end = search(line, "]", start);
            if(end == -1) break;

            string bracket_content = line[start+1..end-1];
            mapping parsed = parse_bracket_content(bracket_content, txd, userid);

            if(parsed) {
                string ptype = parsed["type"];
                if(ptype == "input") {
                    has_input = 1;
                    raw_segments += ({parsed});
                }
                else if(ptype == "submit") {
                    has_submit = 1;
                    raw_segments += ({parsed});
                }
                else if(ptype != "skip") {
                    raw_segments += ({parsed});
                }
            }
            current = end + 1;
        }

        // 处理表单逻辑
        if(has_submit && in_form) {
            // 找到submit segment
            mapping submit_seg;
            foreach(raw_segments, mapping seg) {
                if(seg["type"] == "submit") {
                    submit_seg = seg;
                    break;
                }
            }

            if(submit_seg) {
                // 创建form-submit segment，包含所有积累的输入框
                mapping form_submit = ([
                    "type": "form-submit",
                    "label": submit_seg["label"],
                    "cmd": submit_seg["cmd"],
                    "inputs": form_inputs,
                    "class": submit_seg["class"] || "btn btn-outline-info btn-sm"
                ]);

                // 更新之前行中的输入框标记
                foreach(form_line_indices, int line_idx) {
                    if(result[line_idx] && result[line_idx]["segments"]) {
                        foreach(result[line_idx]["segments"], mapping seg) {
                            if(seg["type"] == "input") {
                                seg["inForm"] = 1;
                            }
                        }
                    }
                }

                // 当前行：添加form-submit和其他非input元素
                array final_segments = ({});
                foreach(raw_segments, mapping seg) {
                    if(seg["type"] == "submit") {
                        final_segments += ({form_submit});
                    } else if(seg["type"] != "input") {
                        final_segments += ({seg});
                    }
                }
                result += ({(["type": "line", "segments": final_segments])});

                // 重置表单状态
                form_inputs = ({});
                form_line_indices = ({});
                in_form = 0;
            }
        }
        else if(has_input) {
            // 有输入框，加入表单状态
            array final_segments = ({});
            foreach(raw_segments, mapping seg) {
                if(seg["type"] == "input") {
                    mapping input_seg = ([
                        "type": "input",
                        "name": seg["name"],
                        "default": seg["default"] || "",
                        "width": seg["width"] || "",
                        "isPassword": seg["isPassword"] || 0,
                        "inForm": 0,  // 后续有submit时会改成1
                        "txd": txd
                    ]);
                    final_segments += ({input_seg});
                    form_inputs += ({input_seg});
                    in_form = 1;
                } else {
                    final_segments += ({seg});
                }
            }

            int line_idx = sizeof(result);
            result += ({(["type": "line", "segments": final_segments])});
            form_line_indices += ({line_idx});
        }
        else {
            // 普通行，使用原有解析
            array segments = parse_line_segments(line, txd, userid);
            result += ({(["type": "line", "segments": segments])});
        }
    }

    // 如果仍有未提交的表单输入，显示独立确定按钮
    if(in_form && sizeof(form_inputs) > 0) {
        foreach(form_line_indices, int line_idx) {
            if(result[line_idx] && result[line_idx]["segments"]) {
                foreach(result[line_idx]["segments"], mapping seg) {
                    if(seg["type"] == "input") {
                        seg["inForm"] = 0;
                    }
                }
            }
        }
    }

    return result;
}

/**
 * 解析一行中的多个段落
 */
array(mapping) parse_line_segments(string line, string txd, string userid)
{
    array(mapping) segments = ({});
    int current = 0;

    while(current < sizeof(line)) {
        int start = search(line, "[", current);
        if(start == -1) {
            if(current < sizeof(line)) {
                string text = line[current..];
                segments += ({parse_text_segment(text)});
            }
            break;
        }
        if(start > current) {
            string text = line[current..start-1];
            segments += ({parse_text_segment(text)});
        }
        int end = search(line, "]", start);
        if(end == -1) {
            segments += ({parse_text_segment(line[start..])});
            break;
        }

        string bracket_content = line[start+1..end-1];
        mapping parsed = parse_bracket_content(bracket_content, txd, userid);
        if(parsed && parsed["type"] != "skip") {
            segments += ({parsed});
        }
        // else: parsed是0或type是"skip"时，完全跳过不渲染
        // 不要将submit按钮转换为文本显示
        current = end + 1;
    }

    return segments;
}

/**
 * 解析文本段落（处理颜色代码）
 */
mapping parse_text_segment(string text)
{
    if(!sizeof(text)) return 0;

    array(mapping) parts = ({});
    int i = 0;

    while(i < sizeof(text)) {
        // 检查颜色代码 § (0xc2 0xa7 in UTF-8)
        if(i < sizeof(text) - 2 && (text[i] & 0xff) == 0xc2 && (text[i+1] & 0xff) == 0xa7) {
            int color_code = text[i+2] & 0xff;
            string color_class = "";

            switch(color_code) {
                case 0x30: color_class = "color-black"; break;
                case 0x31: color_class = "color-red-bold"; break;
                case 0x32: color_class = "color-green-bold"; break;
                case 0x33: color_class = "color-blue-bold"; break;
                case 0x34: color_class = "color-cyan-bold"; break;
                case 0x35: color_class = "color-purple-bold"; break;
                case 0x36: color_class = "color-orange-bold"; break;
                case 0x37: color_class = "color-gray"; break;
                case 0x38: color_class = "color-dark-gray"; break;
                case 0x39: color_class = "color-light-gray"; break;
                // 小写字母颜色码 (WAPMUD扩展)
                case 0x61: color_class = "color-red"; break;      // a
                case 0x62: color_class = "color-green"; break;     // b
                case 0x63: color_class = "color-cyan"; break;      // c
                case 0x64: color_class = "color-purple"; break;    // d
                case 0x65: color_class = "color-yellow"; break;    // e
                case 0x66: color_class = "color-white"; break;     // f
                case 0x67: color_class = "color-gold"; break;      // g
                case 0x72: parts += ({(["type": "color-end"])}); i += 3; continue;  // r = reset
                case 0x78: color_class = "color-bold"; break;     // x
				// 大写亮色码是游戏既有协议；旧解析器漏掉后会把码位
				// 字母本身渲染出来，例如 §C 变成技能名前缀 C。
				case 0x41: color_class = "color-bright-green-bold"; break; // A
				case 0x42: color_class = "color-bright-blue-bold"; break;  // B
				case 0x43: color_class = "color-red-bold"; break;   // C
				case 0x44: color_class = "color-hot-pink-bold"; break; // D
				case 0x45: color_class = "color-bright-gold-bold"; break; // E
				case 0x46: color_class = "color-bright-white-bold"; break; // F
				case 0x59: color_class = "color-bright-yellow-bold"; break; // Y
				case 0x52: parts += ({(["type": "color-end"])}); i += 3; continue; // R
                default: i += 2; continue;
            }

            parts += ({(["type": "color-start", "class": color_class])});
            i += 3;
        }
        else if((text[i] & 0xff) >= 0 && (text[i] & 0xff) < 128) {
            int c = text[i];
            if(c == '&') {
                parts += ({(["type": "text", "content": "&amp;"])});
            } else {
                parts += ({(["type": "text", "content": sprintf("%c", c)])});
            }
            i++;
        }
        else {
            // UTF-8多字节字符
            int byte_count = 2;
            int first_byte = text[i] & 0xff;
            if((first_byte & 0xE0) == 0xC0) byte_count = 2;
            else if((first_byte & 0xF0) == 0xE0) byte_count = 3;
            else if((first_byte & 0xF8) == 0xF0) byte_count = 4;

            if(i + byte_count - 1 < sizeof(text)) {
                parts += ({(["type": "text", "content": text[i..i+byte_count-1]])});
                i += byte_count;
            } else {
                parts += ({(["type": "text", "content": text[i..]])});
                i = sizeof(text);
            }
        }
    }

    return (["type": "text", "parts": parts]);
}

/**
 * 解析方括号内容 [label:command] 等
 */
string query_visual_action_kind(string action_cmd)
{
	string cmd = String.trim_all_whites(action_cmd || "");
	if(cmd=="chars npc" || has_prefix(cmd,"char_npc "))
		return "monster";
	if(cmd=="chars player" || has_prefix(cmd,"char "))
		return "player";
	if(cmd=="items" || has_prefix(cmd,"item "))
		return "item";
	return "";
}

mapping parse_bracket_content(string content, string txd, string userid)
{
    string var_name, default_val, width, type, label, action_cmd;

    // 输入框 [类型 变量名:...] 或 [变量名:默认值...宽度]
    if(sscanf(content, "%s %s:..*%s...*%s", type, var_name, default_val, width) == 4 ||
       sscanf(content, "%s:..*%s...*%s", var_name, default_val, width) == 3) {
        return ([
            "type": "input",
            "name": var_name,
            "default": default_val,
            "width": width,
            "isPassword": (type == "passwd"),
            "txd": txd
        ]);
    }
    // submit按钮 [submit 确定:command ...] - 返回submit类型用于表单处理
    else if(search(content, "submit ") == 0) {
        // 解析: submit 标签:命令 ...
        string submit_label, submit_cmd;
        if(sscanf(content, "submit %s:%s ...", submit_label, submit_cmd) == 2) {
            string css_class = get_button_css_class(submit_label);
            return ([
                "type": "submit",
                "label": submit_label,
                "cmd": submit_cmd,
                "class": css_class
            ]);
        }
        // 解析失败则跳过
        return (["type": "skip"]);
    }
    else if(sscanf(content, "%s %s:...", type, var_name) == 2) {
        // 特殊处理word输入框：如果是"word"，返回cmd-input类型
        // 因为bc_confirm.pike需要word参数，格式是"word=xxx"
        if(var_name == "word") {
            http_werror("[DEBUG] word input detected, using cmd-input type\n");
            return ([
                "type": "cmd-input",
                "name": var_name,
                "cmd": "bc_confirm",
                "txd": txd,
                "placeholder": "请输入您想说的话"
            ]);
        }
        return ([
            "type": "input",
            "name": var_name,
            "default": "",
            "width": "",
            "isPassword": (type == "passwd" || type == "password"),
            "txd": txd
        ]);
    }
    // 检查是否以 ":..." 结尾 (Pike没有has_suffix函数)
    else if(search(content, ":") > 0 && sizeof(content) >= 4 && content[sizeof(content)-4..] == ":...") {
        int colon_pos = search(content, ":");
        string cmd_name = content[0..colon_pos-1];
        return ([
            "type": "cmd-input",
            "cmd": cmd_name,
            "txd": txd
        ]);
    }
    // 处理 [类型:变量名: ...] 格式（如 [string:manage_userMain ...]）
    // 检查是否以 " ...]" 结尾
    else if(sizeof(content) >= 6 && content[sizeof(content)-6..] == " ...]") {
        // 去掉开头的 [ 和结尾的: ...]
        string inner = content[1..sizeof(content)-6];  // 去掉 [ 和 : ...]
        // 查找第一个 : 分隔类型和变量名
        int colon_pos = search(inner, ":");
        if(colon_pos > 0) {
            type = inner[0..colon_pos-1];
            var_name = inner[colon_pos+1..];
            // 检查类型是否是已知的输入类型
            if(type == "string" || type == "passwd" || type == "password" ||
               type == "int" || type == "number" || type == "float") {
                return ([
                    "type": "input",
                    "name": var_name,
                    "default": "",
                    "width": "",
                    "isPassword": (type == "passwd" || type == "password"),
                    "txd": txd
                ]);
            }
        }
        // 如果不是 [类型:变量名: ...] 格式，回退到原来的 cmd-input 处理
        string cmd_name = content[0..sizeof(content)-5];
        return ([
            "type": "cmd-input",
            "cmd": cmd_name,
            "txd": txd
        ]);
    }
    // 处理 类型:变量名 ... 格式（如 string:manage_userMain ...）
    // 注意：这里content没有方括号，已经被strip掉了
    // 检查是否以 " ..." 结尾
    else if(sizeof(content) >= 4 && content[sizeof(content)-4..] == " ...") {
        // 去掉结尾的 " ..."
        string prefix = content[0..sizeof(content)-4];
        // 检查是否是 类型:变量名 格式
        int colon_pos = search(prefix, ":");
        if(colon_pos > 0) {
            type = String.trim_all_whites(prefix[0..colon_pos-1]);
            var_name = String.trim_all_whites(prefix[colon_pos+1..]);
            // 检查类型是否是已知的输入类型
            if(type == "string" || type == "passwd" || type == "password" ||
               type == "int" || type == "number" || type == "float") {
                return (([
                    "type": "input",
                    "name": var_name,
                    "default": "",
                    "width": "",
                    "isPassword": (type == "passwd" || type == "password"),
                    "txd": txd
                ]));
            }
        }
        // 不是已知类型，回退到 cmd-input
        string cmd_name = String.trim_all_whites(prefix);
        return (([
            "type": "cmd-input",
            "cmd": cmd_name,
            "txd": txd
        ]));
    }
	else {
		int pos = search(content, ":");
		if(pos > 0) {
			label = content[0..pos-1];
			action_cmd = content[pos+1..];
			int story_cell;
			int story_chapter;

			// 八十一章各自使用独立的AI插画。章节号必须与文件名完全
			// 一致，客户端不能借图片协议读取任意静态文件。
			if(sscanf(label,"storypic %d",story_chapter)==1 &&
			   label=="storypic "+(string)story_chapter &&
			   story_chapter>=1 && story_chapter<=81 &&
			   action_cmd==sprintf(
				"/xd/images/illusion_s1/story/chapters/chapter_%03d.png",
				story_chapter)){
				string story_path = action_cmd;
				if(sscanf(story_path,"/%*s/images/%s",string story_rest)==2)
					story_path = "/images/"+story_rest;
				return ([
					"type":"story-image","src":story_path,
					"alt":"新月长生劫第"+(string)story_chapter+"章插画",
					"cell":0,"full":1,"chapter":story_chapter,
				]);
			}

			// 九卷故事图使用一张严格3x3图集。服务端只接受固定
			// 项目路径与1..9格号，Vue按格裁切，避免81张大图拖慢镜像。
			if(sscanf(label,"storyimg %d",story_cell)==1 &&
			   label=="storyimg "+(string)story_cell &&
			   story_cell>=1 && story_cell<=9 &&
			   has_prefix(action_cmd,
				"/xd/images/illusion_s1/story/volume_") &&
			   has_suffix(action_cmd,".png") &&
			   search(action_cmd,"..")==-1){
				string story_path = action_cmd;
				if(sscanf(story_path,"/%*s/images/%s",string story_rest)==2)
					story_path = "/images/"+story_rest;
				return ([
					"type":"story-image","src":story_path,
					"alt":"新月长生劫第"+(string)story_cell+"幕",
					"cell":story_cell,
				]);
			}

			// 图片链接 [imgurl xxx:/images/...] 或 [miniimg xxx:/xd/images/...]
            // 支持任意第二部分，如: imgurl picture, imgurl loading, miniimg minipicture 等
            int is_imgurl = (search(label, "imgurl ") == 0);
            int is_miniimg = (search(label, "miniimg ") == 0);

            if(is_imgurl || is_miniimg) {
                // 提取图片路径
                string image_path = action_cmd;
                // 如果 action_cmd 以 picture: 或 loading: 等开头，去掉前缀
                int colon_in_path = search(image_path, ":");
                if(colon_in_path >= 0) {
                    image_path = image_path[colon_in_path+1..];
                }
                // 移除游戏前缀 /xd/ 或 /tx/ 等，转换为正确的Web路径
                // 例如: /xd/images/humanlike_male.gif -> /images/humanlike_male.gif
                if(sscanf(image_path, "/%*s/images/%s", string rest) == 2) {
                    image_path = "/images/" + rest;
                }
                return ([
                    "type": "image",
                    "src": image_path,
                    "alt": "图片"
                ]);
            }
            // URL链接 [url 显示文本:https://...]
            else if(search(label, "url ") == 0 &&
               (search(action_cmd, "http://") == 0 || search(action_cmd, "https://") == 0)) {
                return ([
                    "type": "url-link",
                    "text": label[4..],
                    "url": action_cmd
                ]);
            } else {
                // 普通按钮 - 处理标签中的颜色代码
                string hidden_cmd = hide_command(userid, action_cmd);
                string css_class = get_button_css_class(label);
                string processed_label = process_color_codes(label);
                string visual_kind = query_visual_action_kind(action_cmd);
                mapping result = ([
                    "type": "button",
                    "label": processed_label,
                    "cmd": hidden_cmd,
                    "class": css_class
                ]);
				// 只暴露表现层所需的语义分类，绝不把原始MUD命令或
				// 房间对象路径发送给浏览器。
				if(visual_kind!="")
					result["visual_kind"] = visual_kind;
				return result;
            }
        }
    }

    return 0;
}

/**
 * 处理字符串中的颜色代码，返回HTML
 * 将 §X...§r 转换为 <span class="color-...">...</span>
 */
string process_color_codes(string text)
{
    if(!text || sizeof(text) == 0) return text;

    string result = "";
    int i = 0;
    string current_class = "";

    while(i < sizeof(text)) {
        // 检查颜色代码 § (0xc2 0xa7 in UTF-8)
        if(i < sizeof(text) - 2 && (text[i] & 0xff) == 0xc2 && (text[i+1] & 0xff) == 0xa7) {
            int color_code = text[i+2] & 0xff;

            // 先关闭之前的span
            if(sizeof(current_class) > 0) {
                result += "</span>";
                current_class = "";
            }

            string color_class = "";
            int is_reset = 0;

            switch(color_code) {
                case 0x30: color_class = "color-black"; break;
                case 0x31: color_class = "color-red-bold"; break;
                case 0x32: color_class = "color-green-bold"; break;
                case 0x33: color_class = "color-blue-bold"; break;
                case 0x34: color_class = "color-cyan-bold"; break;
                case 0x35: color_class = "color-purple-bold"; break;
                case 0x36: color_class = "color-orange-bold"; break;
                case 0x37: color_class = "color-gray"; break;
                case 0x38: color_class = "color-dark-gray"; break;
                case 0x39: color_class = "color-light-gray"; break;
                // 小写字母颜色码
                case 0x61: color_class = "color-red"; break;      // a
                case 0x62: color_class = "color-green"; break;     // b
                case 0x63: color_class = "color-cyan"; break;      // c
                case 0x64: color_class = "color-purple"; break;    // d
                case 0x65: color_class = "color-yellow"; break;    // e
                case 0x66: color_class = "color-white"; break;     // f
                case 0x67: color_class = "color-gold"; break;      // g
                case 0x72: is_reset = 1; break;                   // r = reset
                case 0x78: color_class = "color-bold"; break;     // x
				case 0x41: color_class = "color-bright-green-bold"; break; // A
				case 0x42: color_class = "color-bright-blue-bold"; break;  // B
				case 0x43: color_class = "color-red-bold"; break;   // C
				case 0x44: color_class = "color-hot-pink-bold"; break; // D
				case 0x45: color_class = "color-bright-gold-bold"; break; // E
				case 0x46: color_class = "color-bright-white-bold"; break; // F
				case 0x59: color_class = "color-bright-yellow-bold"; break; // Y
				case 0x52: is_reset = 1; break;                     // R
                default: break;
            }

            if(is_reset) {
                // 重置颜色，不开启新span
            } else if(sizeof(color_class) > 0) {
                result += "<span class='" + color_class + "'>";
                current_class = color_class;
            }

            i += 3;
        }
        else {
            // 普通字符，需要转义HTML特殊字符
            int c = text[i] & 0xff;
            if(c == '&') {
                result += "&amp;";
                i++;
            } else if(c == '<') {
                result += "&lt;";
                i++;
            } else if(c == '>') {
                result += "&gt;";
                i++;
            } else if(c == '"') {
                result += "&quot;";
                i++;
            } else if(c == '\'') {
                result += "&#039;";
                i++;
            } else if((text[i] & 0xff) >= 0 && (text[i] & 0xff) < 128) {
                result += sprintf("%c", c);
                i++;
            } else {
                // UTF-8多字节字符
                int byte_count = 2;
                int first_byte = text[i] & 0xff;
                if((first_byte & 0xE0) == 0xC0) byte_count = 2;
                else if((first_byte & 0xF0) == 0xE0) byte_count = 3;
                else if((first_byte & 0xF8) == 0xF0) byte_count = 4;
                else if((first_byte & 0xC0) == 0x80) byte_count = 1;
                else byte_count = 2;

                if(i + byte_count <= sizeof(text)) {
                    result += text[i..i+byte_count-1];
                } else {
                    result += text[i..];
                }
                i += byte_count;
            }
        }
    }

    // 关闭未关闭的span
    if(sizeof(current_class) > 0) {
        result += "</span>";
    }

    return result;
}

// get_button_css_class 已移至 html_renderer.pike 模块

void handle_api_partitions(Protocols.HTTP.Server.Request req)
{
    send_json(req, ([
        "partitions": LOGICALZONED->query_public_partitions(),
        "game_area": getenv("GAME_AREA") || "01",
        "logical_zones": LOGICALZONED->query_public_status()
    ]));
}

void handle_api_challenge(Protocols.HTTP.Server.Request req)
{
    string salt = "";
    for(int i = 0; i < 32; i++) {
        int r = random(62);
        if(r < 26) salt += sprintf("%c", 'a' + r);
        else if(r < 52) salt += sprintf("%c", 'A' + r - 26);
        else salt += sprintf("%c", '0' + r - 52);
    }

    string timestamp = sprintf("%d", time());
    send_json(req, ([
        "challenge": salt + ":" + timestamp,
        "timestamp": (int)timestamp
    ]));
}

void handle_api_status(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);

    if(!txd || txd == "" || txd == " ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }

    string userid = auth["userid"];
    // 人物状态属于自动轮询，只读请求不能延长在线时间。
    object player = get_player_from_connection(userid, 0);

    // 如果虚拟连接池中没有，尝试从 find_player 获取
    if(!player) {
        player = find_player(userid);
    }

    if(!player) {
        mapping forced_logout = ACCOUNT_CHARACTERD->
            query_recent_forced_logout(userid);
        if((int)forced_logout["forced_logout"])
            send_json(req,forced_logout,409);
        else
            send_json(req, ([ "error": "玩家未登录" ]), 401);
        return;
    }

    mapping result = query_player_state(player);
    if(!send_json_mapping_async(req,result,200))
        send_json(req,result);
}

/**
 * 轻量保活接口：只更新 HTTP 虚拟连接时间，不执行 MUD 命令、不生成页面。
 */
void handle_api_ping(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);
    mapping auth;
    object player;
    string userid;

    if(!txd || txd == "" || txd == " ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }
    auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }
    userid = (string)auth["userid"];
    player = get_player_from_connection(userid,1);
    if(!player) {
        send_json(req, ([ "error": "玩家未登录" ]), 401);
        return;
    }
    send_json(req, ([ "ok":1, "timestamp":time() ]));
}

string build_autofight_view_json_job(string output,string txd,
    string userid,mapping metadata,mapping refresh_snapshot)
{
    array(mapping) lines = ({});
    mapping result = copy_value(metadata || ([]));
    if(output!="")
        lines = parse_mud_to_json(output,txd,userid);
    result["lines"] = lines;
    result["userid"] = userid;
    result["refresh"] = refresh_snapshot || ([]);
    result["timestamp"] = time();
    return Standards.JSON.encode(result);
}

/**
 * 读取服务端统一调度的挂机画面。该接口不执行 MUD 命令、不推进战斗；
 * 文本解析与 JSON 编码进入响应线程池。
 */
void handle_api_autofight_view(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);
    mapping auth;
    mapping snapshot;
    mapping forced_logout;
    mapping refresh_snapshot;
    mapping metadata;
    object player;
    string userid;
    string output;
    string after_generation;
    string generation;
    int after_sequence;
    int sequence;

    if(!txd || txd=="" || txd==" "){
        send_json(req,(["error":"需要认证信息：txd"]),400);
        return;
    }
    auth = decode_txd(txd);
    if(!auth){
        send_json(req,(["error":"TXD认证信息无效"]),401);
        return;
    }
    userid = (string)auth["userid"];
    player = get_player_from_connection(userid,0);
    if(!player){
        forced_logout = ACCOUNT_CHARACTERD->
            query_recent_forced_logout(userid);
        if((int)forced_logout["forced_logout"])
            send_json(req,forced_logout,409);
        else
            send_json(req,(["error":"玩家未登录"]),401);
        return;
    }

    AUTOFIGHTD->initialize_player(player);
    after_sequence = (int)params["after"];
    after_generation = (string)params["generation"];
    generation = AUTOFIGHTD->query_server_autofight_view_generation();
    snapshot = AUTOFIGHTD->query_server_autofight_view(player);
    sequence = (int)snapshot["sequence"];
    refresh_snapshot = query_autofight_refresh_snapshot(player);
    metadata = ([
        "sequence":sequence,
        "generation":generation,
        "updated_at":(int)snapshot["updated_at"],
        "active":functionp(player->query_autofight) &&
            player->query_autofight()=="enable" ? 1 : 0,
    ]);
    if(sequence<=0 || (generation==after_generation &&
       sequence<=after_sequence)){
        metadata["unchanged"] = 1;
        metadata["refresh"] = refresh_snapshot;
        metadata["timestamp"] = time();
        if(!send_json_mapping_async(req,metadata,200))
            send_json(req,metadata);
        return;
    }
    output = (string)snapshot["output"];
    if(!send_json_builder_async(req,build_autofight_view_json_job,({
        output,txd,userid,metadata,refresh_snapshot
    }),200))
        send_json(req,(["error":"响应线程池繁忙，请稍后重试"]),503);
}

/**
 * 查询玩家当前的真实交战目标。
 *
 * 战斗核心已经通过 query_enemy() 维护当前目标，优先使用它可以正确
 * 识别普通怪物、玩家和方士召唤兽参与的战斗。房间扫描仅作为旧对象
 * 没有完整战斗接口时的兼容兜底。
 */
object|zero query_battle_enemy(object player)
{
    if(!player)
        return 0;

    object room = environment(player);
    if(!room)
        return 0;

    object|zero enemy_obj = 0;
    if(functionp(player->query_enemy)) {
        enemy_obj = player->query_enemy();
        if(enemy_obj && environment(enemy_obj) == room &&
           LOGICALZONED->can_action("combat",player,enemy_obj))
            return enemy_obj;
    }

    array inv = all_inventory(room,player);
    foreach(inv, object ob) {
        if(ob == player)
            continue;
        if(functionp(ob->query_in_combat) && ob->query_in_combat() &&
           functionp(ob->query_enemy) && ob->query_enemy() == player)
            return ob;
        if(functionp(ob->query_in_combat) && ob->query_in_combat() &&
           functionp(ob->query_attack_target) &&
           ob->query_attack_target() == player)
            return ob;
    }

    foreach(inv, object ob) {
        if(ob == player)
            continue;
        if((functionp(ob->is_npc) || functionp(ob->query_player)) &&
           functionp(ob->query_in_combat) && ob->query_in_combat())
            return ob;
    }

    return 0;
}

/**
 * 将交战目标转换为 Vue 战斗小窗需要的完整状态。
 */
mapping query_battle_enemy_state(object enemy_obj)
{
    mapping enemy_state = ([]);
    if(!enemy_obj)
        return enemy_state;

    string e_name = "未知";
    if(functionp(enemy_obj->query_name))
        e_name = enemy_obj->query_name();
    enemy_state["name"] = e_name;

    string e_name_cn = e_name;
    if(functionp(enemy_obj->query_name_cn))
        e_name_cn = enemy_obj->query_name_cn();
    if(!e_name_cn || e_name_cn == "")
        e_name_cn = e_name && e_name != "" ? e_name : "目标识别中";
    enemy_state["name_cn"] = e_name_cn;

    int e_is_npc = 1;
    if(functionp(enemy_obj->is_npc))
        e_is_npc = enemy_obj->is_npc();
    enemy_state["is_npc"] = e_is_npc;

    if(functionp(enemy_obj->query_level))
        enemy_state["level"] = enemy_obj->query_level();

    if(functionp(enemy_obj->query_profeId))
        enemy_state["profe_id"] = enemy_obj->query_profeId();
    if(functionp(enemy_obj->query_profe_cn) &&
       functionp(enemy_obj->query_profeId))
        enemy_state["profe"] =
            enemy_obj->query_profe_cn(enemy_obj->query_profeId());

    if(functionp(enemy_obj->query_raceId))
        enemy_state["race_id"] = enemy_obj->query_raceId();
    if(functionp(enemy_obj->query_race_cn) &&
       functionp(enemy_obj->query_raceId))
        enemy_state["race"] =
            enemy_obj->query_race_cn(enemy_obj->query_raceId());

    if(functionp(enemy_obj->query_low_attack_desc) &&
       functionp(enemy_obj->query_high_attack_desc)) {
        int attack_low = enemy_obj->query_low_attack_desc();
        int attack_high = enemy_obj->query_high_attack_desc();
        enemy_state["attack_low"] = attack_low;
        enemy_state["attack_high"] = attack_high;
        enemy_state["attack"] = attack_high;
    } else if(functionp(enemy_obj->query_attack_power)) {
        enemy_state["attack"] = enemy_obj->query_attack_power();
        enemy_state["attack_low"] = enemy_state["attack"];
        enemy_state["attack_high"] = enemy_state["attack"];
    }
    if(functionp(enemy_obj->query_defend_power))
        enemy_state["defend"] = enemy_obj->query_defend_power();

    int e_hp = 0;
    int e_hp_max = 0;
    if(functionp(enemy_obj->get_cur_life))
        e_hp = enemy_obj->get_cur_life();
    if(functionp(enemy_obj->query_life_max))
        e_hp_max = enemy_obj->query_life_max();
    if(e_hp < 0)
        e_hp = 0;

    enemy_state["hp"] = e_hp;
    enemy_state["hp_max"] = e_hp_max;
    enemy_state["is_dead"] = (e_hp <= 0);

    if(!e_is_npc && functionp(enemy_obj->query_userid))
        enemy_state["userid"] = enemy_obj->query_userid();

    return enemy_state;
}

/**
 * 挂机命令完成后一次性生成只读战斗快照，替代浏览器紧接着再发一条
 * /api/battle_status 请求。快照仍在 Backend 读取，线程池只做后续
 * 文本解析和 JSON 编码。
 */
mapping query_autofight_refresh_snapshot(object player)
{
    mapping snapshot = ([]);
    mapping player_state;
    object|zero enemy_obj = 0;
    int in_battle = 0;

    if(!player)
        return snapshot;
    player_state = query_player_state(player);
    snapshot["player"] = player_state;
    if(functionp(player->query_in_combat))
        in_battle = player->query_in_combat();
    snapshot["in_battle"] = in_battle ? 1 : 0;
    if(in_battle){
        enemy_obj = query_battle_enemy(player);
        if(enemy_obj)
            snapshot["enemy"] = query_battle_enemy_state(enemy_obj);
        else
            snapshot["enemy"] = 0;
    }
    return snapshot;
}

/**
 * 获取战斗状态 API
 * 返回玩家和敌人的状态信息
 */
void handle_api_battle_status(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);

    if(!txd || txd == "" || txd == " ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }

    string userid = auth["userid"];
    // 只读API：不更新闲置时间
    object player = get_player_from_connection(userid, 0);

    if(!player) {
        send_json(req, ([ "error": "玩家未登录" ]), 401);
        return;
    }

    // 获取玩家状态
    mapping player_state = query_player_state(player);
    player_state["userid"] = userid;

    // 查找敌人
    mapping enemy_state = ([]);

    // 方法1: 检查玩家是否在战斗中
    int in_combat = 0;
    if(functionp(player->query_in_combat)) {
        in_combat = player->query_in_combat();
    }

    if(!in_combat) {
        // 不在战斗中
        mapping idle_result = ([
            "in_battle": false,
            "player": player_state
        ]);
        if(!send_json_mapping_async(req,idle_result,200))
            send_json(req,idle_result);
        return;
    }

    // 获取当前房间和战斗核心维护的真实敌人
    object room = environment(player);
    if(!room) {
        mapping roomless_result = ([
            "in_battle": true,
            "player": player_state,
            "enemy": 0
        ]);
        if(!send_json_mapping_async(req,roomless_result,200))
            send_json(req,roomless_result);
        return;
    }

    object|zero enemy_obj = query_battle_enemy(player);
    if(enemy_obj)
        enemy_state = query_battle_enemy_state(enemy_obj);

    // http_werror(" battle_status response: in_battle=%d, enemy=%O\n", 1, enemy_obj ? enemy_state : 0);
    mapping battle_result = ([
        "in_battle": true,
        "player": player_state,
        "enemy": enemy_obj ? enemy_state : 0
    ]);
    if(!send_json_mapping_async(req,battle_result,200))
        send_json(req,battle_result);
}

mapping execute_autofight_api_action(object player,string action)
{
    int new_state = 0;
    int vip_level;
    string current;
    string reason;
    mapping result;

    AUTOFIGHTD->initialize_player(player);
    current = player->query_autofight();

    if(action == "on" || (action == "toggle" && current != "enable")) {
        reason = AUTOFIGHTD->query_start_block_reason(player);
        if(reason != "") {
            AUTOFIGHTD->stop_autofight(player);
            result = ([
                "autofight":0,
                "message":"无法开启自动挂机："+reason,
            ]);
            if(AUTOFIGHTD->is_quota_exhausted_reason(player,reason)){
                vip_level = AUTOFIGHTD->query_vip_level(player);
                result["quota_exhausted"] = 1;
                result["vip_level"] = vip_level;
                result["daily_hours"] =
                    AUTOFIGHTD->query_daily_seconds_for(player)/3600;
                result["can_upgrade_vip"] =
                    AUTOFIGHTD->can_upgrade_daily_time(player);
                result["upgrade_command"] = vip_level < VIP_MAX_LEVEL ?
                    "vip_service_list" : "autofight vip";
                result["upgrade_label"] = vip_level < VIP_MAX_LEVEL ?
                    "提高VIP" : "查看权益";
            }
            return result;
        }
        AUTOFIGHTD->start_autofight(player);
        new_state = 1;
    } else {
        AUTOFIGHTD->stop_autofight(player);
        new_state = 0;
    }

    return ([
        "autofight":new_state,
        "message":new_state ?
            "自动挂机已开启：智能寻路会选择练级区，并在空图时自动前往相邻地图" :
            "自动挂机已关闭",
    ]);
}

void handle_api_autofight(Protocols.HTTP.Server.Request req)
{
    if(req->request_type != "POST") {
        send_json(req, ([ "error": "只支持 POST 请求" ]), 405);
        return;
    }

    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);
    string action = url_decode(params["action"] || "toggle");

    if(!txd || txd == "" || txd == " ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }

    string userid = auth["userid"];
    // 用户主动操作：更新闲置时间
    object player = get_player_from_connection(userid, 1);

    if(!player) {
        send_json(req, ([ "error": "玩家未登录" ]), 401);
        return;
    }

    object user_mutex;
    object user_key;
    mapping result = ([]);
    mixed action_err;

    if(!functionp(player->query_autofight) ||
       !functionp(player->set_autofight)) {
        send_json(req, ([ "error": "自动挂机模块尚未加载，请稍后重试" ]), 503);
        return;
    }

    user_mutex = query_user_command_mutex(userid);
    user_key = user_mutex->lock();
    action_err = catch {
        result = execute_autofight_api_action(player,action);
    };
    destruct(user_key);

    if(action_err){
        http_werror(" Autofight action error: %s\n",
            describe_error(action_err));
        send_json(req,(["error":"自动挂机状态切换失败"]),500);
        return;
    }
    send_json(req,result);
}

/**
 * 获取可用招式列表 API
 * 通过执行 MUD 命令获取招式列表，兼容不同 MUD 实现
 */
void handle_api_performs(Protocols.HTTP.Server.Request req)
{
    mixed err = catch {
        mapping params = get_params(req);
        string txd = url_decode(params["txd"]);

        if(!txd || txd == "" || txd == " ") {
            send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
            return;
        }

        mapping auth = decode_txd(txd);
        if(!auth) {
            send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
            return;
        }

        string auth_userid = auth["userid"];
        string auth_password = auth["password"];

        // use_perform 同样进入 Backend 世界命令队列。
        if(!execute_command_async(auth_userid,auth_password,"use_perform",
           finish_handle_api_performs,req,auth_userid,auth_password))
            send_json(req,(["error":"命令队列繁忙，请稍后重试"]),503);
    };

    if(err) {
        werror("[API] /api/performs EXCEPTION: %s\n", describe_error(err));
        send_json(req, ([ "error": "服务器错误" ]), 500);
    }
}

void finish_handle_api_performs(string response,
    Protocols.HTTP.Server.Request req,string auth_userid,
    string auth_password)
{
    mixed err = catch {

        // 生成新的 TXD - 使用存储的明文密码（因为 auth_password 可能是哈希）
        string stored_password = get_user_password(auth_userid);
        string new_txd = generate_txd(auth_userid, stored_password || auth_password);

        array performs_list = ({});
        string skill_name = "xiand";
        string skill_name_cn = "技能";
        int skill_level = 0;
        int in_combat = 0;

        // 检查是否在战斗中
        if(search(response, "察看战况") >= 0 || search(response, "fight") >= 0) {
            in_combat = 1;
        }

        // 解析 xiand 技能列表格式
        // 格式: □[技能名(1级/10%):use_perform skill_id] 或 □[技能名(2级):use_perform skill_id](冷却时间)
        array lines = response / "\n";

        foreach(lines, string line) {
            line = String.trim_all_whites(line);
            if(sizeof(line) == 0) continue;

            // 去掉行首的 □ 标记
            if(line[0] == 0 || line[0] == ' ') {
                line = String.trim_all_whites(line[1..]);
            }

            // 解析 xiand 技能格式: [技能名(1级/10%):use_perform skill_id]
            // 或: [技能名(2级):use_perform skill_id]
            // 或: [技能名:use_perform skill_id]
            string perform_name, perform_id;
            int level = 0;
            int exp_percent = 0;
            int cooling = 0;

            // 检查是否有冷却时间标记 (5s) 或 (3m)
            string clean_line = line;
            if(search(line, "秒") > 0 || search(line, "分") > 0 ||
               search(line, "s)") > 0 || search(line, "m)") > 0) {
                cooling = 1;
            }

            // 尝试匹配带等级和经验的格式: [技能名(1级/10%):use_perform skill_id]
            if(sscanf(line, "[%s(%d级/%d%%):use_perform %s]",
                       perform_name, level, exp_percent, perform_id) == 4) {
                perform_name = String.trim_all_whites(perform_name);
                perform_id = String.trim_all_whites(perform_id);
                performs_list += ({
                    ([
                        "id": perform_id,
                        "name_cn": perform_name,
                        "neili_cost": 0,
                        "level_req": 0,
                        "skill_level": level,
                        "exp_percent": exp_percent,
                        "available": !cooling,
                        "enough_neili": 1,
                        "cooling": cooling
                    ])
                });
            }
            // 尝试匹配满级格式: [技能名(10级):use_perform skill_id]
            else if(sscanf(line, "[%s(%d级):use_perform %s]",
                             perform_name, level, perform_id) == 3) {
                perform_name = String.trim_all_whites(perform_name);
                perform_id = String.trim_all_whites(perform_id);
                performs_list += ({
                    ([
                        "id": perform_id,
                        "name_cn": perform_name,
                        "neili_cost": 0,
                        "level_req": 0,
                        "skill_level": level,
                        "exp_percent": 100,
                        "available": !cooling,
                        "enough_neili": 1,
                        "cooling": cooling
                    ])
                });
            }
            // 尝试匹配基本格式: [技能名:use_perform skill_id]
            else if(sscanf(line, "[%s:use_perform %s]", perform_name, perform_id) == 2) {
                perform_name = String.trim_all_whites(perform_name);
                perform_id = String.trim_all_whites(perform_id);
                performs_list += ({
                    ([
                        "id": perform_id,
                        "name_cn": perform_name,
                        "neili_cost": 0,
                        "level_req": 0,
                        "skill_level": 0,
                        "exp_percent": 0,
                        "available": !cooling,
                        "enough_neili": 1,
                        "cooling": cooling
                    ])
                });
            }
        }

        // 如果通过命令解析失败，尝试直接从玩家对象读取（txpike9兼容）
        if(sizeof(performs_list) == 0) {
            object player = get_player_from_connection(auth_userid);
            if(player) {
                // 尝试获取装备的武功（多种方式）
                object|zero attack_skill = 0;
                if(functionp(player->query_attack_skill)) {
                    attack_skill = player->query_attack_skill();
                } else if(mappingp(player->equipped) && player->equipped["weapon"]) {
                    // 从装备的武器获取武功
                    object weapon = player->equipped["weapon"];
                    if(functionp(weapon->query_skill)) {
                        attack_skill = weapon->query_skill();
                    }
                }

                if(attack_skill) {
                    if(functionp(attack_skill->query_name_cn)) {
                        skill_name_cn = attack_skill->query_name_cn() || "未知武功";
                    }

                    mapping skills = player->skills;
                    if(skills && sizeof(skills) > 0) {
                        // 获取第一个技能的等级
                        foreach(indices(skills), string sk) {
                            if(arrayp(skills[sk]) && sizeof(skills[sk]) > 0) {
                                skill_level = skills[sk][0];
                                break;
                            }
                        }
                    }

                    // 获取内力
                    int player_neili = 0;
                    if(functionp(player->query_neili)) {
                        player_neili = player->query_neili();
                    }

                    // 获取所有可用招式
                    array(object) performs = ({});
                    if(functionp(attack_skill->all_performs)) {
                        performs = attack_skill->all_performs(player);
                    }

                    if(performs && sizeof(performs) > 0) {
                        foreach(performs, object perform_obj) {
                            if(!perform_obj) continue;

                            string perform_id = object_name(perform_obj);
                            string perform_name_cn = perform_obj->name_cn || "";

                            int neili_cost = 0;
                            if(intp(perform_obj->neili_cost)) {
                                neili_cost = perform_obj->neili_cost;
                            } else if(intp(perform_obj->qi_damage)) {
                                neili_cost = perform_obj->qi_damage;
                            }

                            if(sizeof(perform_name_cn) > 0) {
                                performs_list += ({
                                    ([
                                        "id": perform_id,
                                        "name_cn": perform_name_cn,
                                        "neili_cost": neili_cost,
                                        "level_req": 0,
                                        "skill_level": skill_level,
                                        "available": 1,
                                        "enough_neili": player_neili >= neili_cost
                                    ])
                                });
                            }
                        }
                    }
                }
            }
        }

        send_json(req, ([
            "performs": performs_list,
            "skill_name": "xiand",
            "skill_name_cn": skill_name_cn,
            "skill_level": 0,
            "player_neili": 0,
            "in_combat": in_combat,
            "txd": new_txd
        ]));
    };

    if(err) {
        werror("[API] /api/performs EXCEPTION: %s\n", describe_error(err));
        send_json(req, ([ "error": "服务器错误" ]), 500);
    }
}

/**
 * ========================================================================
 * 设置邀请URL API
 * ========================================================================
 *
 * 用于设置玩家的邀请链接URL
 *
 * 请求参数:
 *   - txd: 认证token
 *   - url: 邀请链接URL
 *
 * ========================================================================
 */
void handle_api_invite_seturl(Protocols.HTTP.Server.Request req)
{
    mixed err = catch {
        mapping params = get_params(req);
        string txd = url_decode(params["txd"]);
        string invite_url = url_decode(params["url"]);

        if(!txd || txd == "" || txd == " ") {
            send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
            return;
        }

        mapping auth = decode_txd(txd);
        if(!auth) {
            send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
            return;
        }

        string userid = auth["userid"];

        if(!invite_url || invite_url == "") {
            send_json(req, ([ "error": "缺少url参数" ]), 400);
            return;
        }

        http_werror("[API] /api/invite/seturl: userid=%s, url=%s\n", userid, invite_url);

        // 这里可以将邀请URL保存到用户数据或做其他处理
        // 目前暂时返回成功响应
        send_json(req, ([
            "status": "success",
            "userid": userid,
            "url": invite_url
        ]));
    };

    if(err) {
        http_werror("[API] /api/invite/seturl EXCEPTION: %s\n", describe_error(err));
        send_json(req, ([ "error": "服务器错误" ]), 500);
    }
}

void handle_api_async(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);
    string cmd = params["cmd"];
    if(!cmd || cmd == "") cmd = "look";

    if(!txd || txd == "" || txd == " ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }

    string userid = auth["userid"];
    string stored_password = get_user_password(userid);
    if(!stored_password || auth["password"]!=stored_password) {
        send_json(req, ([ "error": "用户名或密码错误" ]), 401);
        return;
    }
    cmd = unhide_command(userid, cmd);

    string request_id = userid + "_" + sprintf("%d", time() * 1000 + random(999));
    int enqueued = enqueue_user_request(userid, cmd, request_id);

    if(enqueued) {
        send_json(req, ([
            "request_id": request_id,
            "status": "queued",
            "message": "命令已加入队列"
        ]));
    } else {
        send_json(req, ([ "error": "队列已满，请稍后重试" ]), 503);
    }
}

void handle_api_result(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string request_id = params["request_id"];
    string txd = url_decode(params["txd"]);
    string userid, stored_password, authenticated_txd;

    if(!request_id || request_id == "") {
        send_json(req, ([ "error": "缺少request_id参数" ]), 400);
        return;
    }

    if(!txd || txd=="" || txd==" ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }
    userid = auth["userid"];
    stored_password = get_user_password(userid);
    if(!stored_password || auth["password"]!=stored_password) {
        send_json(req, ([ "error": "用户名或密码错误" ]), 401);
        return;
    }
    if(search(request_id,userid+"_")!=0) {
        send_json(req, ([ "error": "请求不属于当前用户" ]), 403);
        return;
    }
    // 严格认证后原样沿用调用方 token，异步结果同样不得改写旧书签格式。
    authenticated_txd = txd;

    string|zero result = get_request_result(request_id);

    if(result == 0) {
        // 更新闲置时间 - 活跃用户不应被踢出
        update_connection_time(userid);
        send_json(req, ([ "status": "pending", "message": "命令正在执行中" ]));
    } else if(result == UNDEFINED) {
        send_json(req, ([ "error": "请求超时或已过期" ]), 408);
    } else {
        // 更新闲置时间 - 活跃用户不应被踢出
        update_connection_time(userid);

        string html = response_to_html(result,userid,"look",
            authenticated_txd);
        mapping resp = ([ ]);
        resp["type"] = "text/html; charset=UTF-8";
        resp["data"] = html;
        resp["error"] = 200;
        resp["extra_heads"] = (["cache-control": "no-cache", "Access-Control-Allow-Origin": "*"]);
        finish_http_response(req,resp);
    }
}

void handle_exits(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);

    if(!txd || txd == "" || txd == " ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }

    string userid = auth["userid"];
    // 只读API：不更新闲置时间
    object player = get_player_from_connection(userid, 0);

    if(!player) {
        send_json(req, ([ "error": "玩家未登录" ]), 401);
        return;
    }

    send_json(req, query_room_exits(player));
}

void handle_room(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = url_decode(params["txd"]);

    if(!txd || txd == "" || txd == " ") {
        send_json(req, ([ "error": "需要认证信息：txd" ]), 400);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "TXD认证信息无效" ]), 401);
        return;
    }

    string userid = auth["userid"];
    // 只读API：不更新闲置时间
    object player = get_player_from_connection(userid, 0);

    if(!player) {
        send_json(req, ([ "error": "玩家未登录" ]), 401);
        return;
    }

    send_json(req, query_room_info(player));
}

void handle_api_chat_messages(Protocols.HTTP.Server.Request req)
{
    mapping params = get_params(req);
    string txd = params["txd"];
    string channel = params["channel"] || "pub_channel";

    if(!txd || txd == "") {
        send_json(req, ([ "error": "缺少txd参数" ]), 401);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "无效的txd" ]), 401);
        return;
    }

    string userid = auth["userid"];

    object chatroomd = find_object(ROOT + "/gamelib/single/daemons/chatroomd");
    if(!chatroomd) {
        chatroomd = load_object(ROOT + "/gamelib/single/daemons/chatroomd");
    }

    if(!chatroomd) {
        send_json(req, ([ "error": "聊天服务不可用" ]), 503);
        return;
    }

    string chat_msg = chatroomd->query_chat_msg(channel, userid);

    array(string) messages = ({});
    if(chat_msg && sizeof(chat_msg)) {
        foreach(chat_msg / "\n", string line) {
            line = String.trim_all_whites(line);
            if(sizeof(line) > 0) {
                string cleaned = clean_chat_message(line);
                if(sizeof(cleaned) > 0) {
                    messages += ({cleaned});
                }
            }
        }
    }

    send_json(req, ([
        "channel": channel,
        "messages": messages,
        "count": sizeof(messages),
        "timestamp": time()
    ]));
}

void handle_api_chat_send(Protocols.HTTP.Server.Request req)
{
    if(req->request_type != "POST") {
        send_json(req, ([ "error": "只支持POST请求" ]), 405);
        return;
    }

    mapping params = get_params(req);
    string txd = params["txd"];
    string channel = params["channel"] || "pub_channel";
    string message = params["message"];

    if(!txd || txd == "") {
        send_json(req, ([ "error": "缺少txd参数" ]), 401);
        return;
    }

    mapping auth = decode_txd(txd);
    if(!auth) {
        send_json(req, ([ "error": "无效的txd" ]), 401);
        return;
    }

    string userid = auth["userid"];
    string password = auth["password"];

    if(!message || message == "") {
        send_json(req, ([ "error": "消息内容不能为空" ]), 400);
        return;
    }

    if(sizeof(message)>1800){
        send_json(req,(["error":"消息内容过长"]),400);
        return;
    }
    if(!execute_command_async(userid,password,"ui_chat "+message,
       finish_handle_api_chat_send,req,channel,message))
        send_json(req,(["error":"命令队列繁忙，请稍后重试"]),503);
}

void finish_handle_api_chat_send(string response,
    Protocols.HTTP.Server.Request req,string channel,string message)
{
    string command_response = String.trim_all_whites(response || "");
    if(has_prefix(command_response,"错误:") ||
       has_prefix(command_response,"{\"error\":")){
        send_json(req,(["error":"消息发送失败，请稍后重试"]),500);
        return;
    }
    send_json(req, ([
        "success": 1,
        "channel": channel,
        "message": message,
        "timestamp": time()
    ]));
}

// ========================================================================
// 辅助查询函数
// ========================================================================

mapping query_room_exits(object player)
{
    mapping result = ([ ]);
    result["timestamp"] = time();
    result["room"] = ([ ]);
    result["exits"] = (["北": 0, "东": 0, "南": 0, "西": 0]);

    object room = environment(player);
    if(!room) {
        result["room"]["name"] = "虚空";
        result["room"]["desc"] = "你处于虚空中...";
        return result;
    }

    if(functionp(room->query_short)) {
        result["room"]["name"] = room->query_short();
    } else if(functionp(room->query_name_cn)) {
        result["room"]["name"] = room->query_name_cn();
    } else {
        result["room"]["name"] = "未知房间";
    }

    if(functionp(room->query_desc)) {
        string desc = room->query_desc();
        if(desc) result["room"]["desc"] = desc;
    }

    if(functionp(room->query_exits)) {
        mapping exits = room->query_exits();
        if(exits && sizeof(exits) > 0) {
            foreach(indices(exits), string dir) {
                string dest_path = exits[dir];
                string dest_name = "";

                if(dest_path && sizeof(dest_path) > 0) {
                    if(search(dest_path, ROOT) != 0 && search(dest_path, "/") != 0) {
                        dest_path = ROOT + "/" + dest_path;
                    } else if(search(dest_path, "/") == 0 && search(dest_path, ROOT) != 0) {
                        dest_path = ROOT + dest_path;
                    }

                    object dest_room = load_object(dest_path);
                    if(dest_room) {
                        if(functionp(dest_room->query_short)) {
                            dest_name = dest_room->query_short();
                        } else if(functionp(dest_room->query_name_cn)) {
                            dest_name = dest_room->query_name_cn();
                        }
                    }
                }

                string norm_dir = normalize_direction(dir);
                array valid_dirs = indices(result["exits"]);
                if(search(valid_dirs, norm_dir) >= 0) {
                    result["exits"][norm_dir] = ([
                        "direction": dir,
                        "command": "leave " + dir,
                        "destination": dest_name || ""
                    ]);
                }
            }
        }
    }

    return result;
}

mapping query_room_info(object player)
{
    mapping result = ([ ]);
    result["timestamp"] = time();
    result["room"] = ([ ]);
    result["npcs"] = ({});

    object room = environment(player);
    if(!room) {
        result["room"]["name"] = "虚空";
        result["room"]["desc"] = "你处于虚空中...";
        return result;
    }

    if(functionp(room->query_short)) {
        result["room"]["name"] = room->query_short();
    } else if(functionp(room->query_name_cn)) {
        result["room"]["name"] = room->query_name_cn();
    } else {
        result["room"]["name"] = "未知房间";
    }

    if(functionp(room->query_desc)) {
        string desc = room->query_desc();
        if(desc) result["room"]["desc"] = desc;
    } else if(functionp(room->query_long)) {
        result["room"]["desc"] = room->query_long();
    }

    array inv = all_inventory(room,player);
    foreach(inv, object ob) {
        if(ob != player && functionp(ob->query_short)) {
            string name = ob->query_short();
            if(name) {
                mapping npc = ([ "name": name ]);
                if(functionp(ob->query_name)) {
                    string ob_name = ob->query_name();
                    if(ob_name && sizeof(ob_name) > 0) {
                        npc["command"] = "look " + ob_name;
                    } else {
                        npc["command"] = "look " + name;
                    }
                } else {
                    npc["command"] = "look " + name;
                }
                result["npcs"] += ({npc});
            }
        }
    }

    return result;
}

// ========================================================================
// 状态查询
// ========================================================================

mapping query_status()
{
    mapping m = ([ ]);
    m["running"] = http_port != 0;
    m["port"] = HTTP_PORT;
    m["api_only"] = api_only_mode;
    m["connections"] = query_connection_status();
    m["queue"] = query_queue_status();
    m["rate_limits"] = query_rate_limit_status();
    m["threads"] = query_thread_status();
    m["async_io"] = ASYNC_IOD->query_status();
    m["runtime"] = query_runtime_performance();
    m["auth_cache"] = query_auth_cache_status();
    m["command_tokens"] = query_hidden_command_status();
    m["pagination"] = query_pagination_status();
    m["performance"] = query_http_performance_status();
    return m;
}
