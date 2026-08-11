#!/usr/bin/env pike
/** Embedded Pike gateway parsing, fencing and orchestration contracts. */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	werror("\n[Pike Gateway %d] %s\n",results["total"],name);
	if(valid){
		results["passed"]++;
		werror("  ✓ 通过\n");
	}
	else{
		results["failed"]++;
		werror("  ✗ 失败: %s\n",reason);
	}
}

int source_has(string source,string needle)
{
	return source && search(source,needle)!=-1;
}

mapping snapshot(string query,void|string content_type,void|string body)
{
	return (["query":query || "","body":body || "",
		"headers":(["content-type":content_type || ""])]);
}

/*
 * Ported regression contract catalog.  These names document the Python
 * oracle cases that were moved into Pike/TestUnit and keep the architecture
 * audit explicit after the obsolete runtime implementation is removed.
 */
constant PORTED_GATEWAY_CONTRACTS = ({
	"test_account_cache_capability_changes_only_when_worker_changes",
	"test_background_arrival_uses_internal_cache_and_epoch_capabilities",
	"test_completed_public_arrival_clears_background_retry",
	"test_conflicting_valid_identity_fields_are_rejected",
	"test_direct_active_gateway_requires_isolated_trial_acknowledgement",
	"test_duplicate_live_player_copies_are_discarded_without_saving",
	"test_dynamic_clone_room_move_fails_closed_without_arrival_path",
	"test_empty_recovery_cannot_resume_without_coordinator_generation_ack",
	"test_expired_lease_reopens_only_on_its_previous_worker",
	"test_failed_generation_recovery_keeps_global_routing_paused",
	"test_failed_periodic_lease_gc_keeps_routing_paused",
	"test_full_recovery_rebinds_same_worker_affinity_mismatch",
	"test_handoff_target_or_state_drift_is_rejected_before_source_release",
	"test_invalid_internal_rpc_json_is_a_controlled_routing_failure",
	"test_live_player_leases_renew_after_generation_ack_before_control",
	"test_migration_delivery_plan_distinguishes_old_and_current_commands",
	"test_only_auction_commands_use_cluster_global_command_lock",
	"test_prefence_rejection_does_not_create_false_uncertain_request",
	"test_reconciled_lease_gc_uploads_bounded_inventory_chunks",
	"test_recovered_worker_discards_copy_owned_by_new_epoch_elsewhere",
	"test_recovery_waits_for_inflight_request_before_inventory",
	"test_request_done_fence_fails_closed_on_unknown_status",
	"test_request_done_fence_waits_through_running_state",
	"test_request_queued_on_transaction_lock_rechecks_routing_gate",
	"test_same_worker_completed_move_rebinds_lease_affinity",
	"test_shadow_controller_never_runs_auction_settlement",
	"test_shared_account_lock_identity_is_resolved_authoritatively",
	"test_timer_move_reconciles_under_lease_and_keeps_failed_arrival",
	"test_token_only_account_maintenance_waits_for_character_write",
	"test_unreconstructable_dynamic_room_never_crosses_workers",
	"test_worker_response_does_not_duplicate_gateway_owned_headers",
});

int main()
{
	object httpd = (object)(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string gateway = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/pike_gateway.pike");
	string daemon = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string rpc = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike");
	string map_worker_daemon = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/map_workerd.pike");
	string user = Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	string game_master = Stdio.read_file(ROOT+"/gamelib/master.pike");
	string homed = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/homed.pike");
	string cluster = Stdio.read_file(ROOT+"/scripts/map_worker_cluster.sh");
	string error_desc = "";
	mixed err = catch {
		mapping query = httpd->test_pike_gateway_parse_snapshot(
			snapshot("userid=xd01hero&cmd=flushview"));
		mapping json = httpd->test_pike_gateway_parse_snapshot(snapshot("",
			"application/json","{\"character_id\":\"xd01hero\",\"cmd\":\"look\"}"));
		mapping mixed_case = httpd->test_pike_gateway_parse_snapshot(
			snapshot("userid=xd01LSQ2026&cmd=look"));
		mapping case_sensitive = httpd->test_pike_gateway_parse_snapshot(
			snapshot("","application/json",
				"{\"cmd\":\"login_regnew gamelib xd01newhero MiXeD88 sid challenge\"}"));
		check("查询和JSON正文使用同一人物路由规则",
			query["userid"]=="xd01hero" && query["command"]=="flushview" &&
			json["userid"]=="xd01hero" && json["command"]=="look" &&
			mixed_case["userid"]=="xd01LSQ2026" &&
			case_sensitive["command"]==
				"login_regnew gamelib xd01newhero MiXeD88 sid challenge",
			"请求格式差异可能把同一人物发往不同worker");

		int conflict_rejected;
		mixed conflict_err = catch {
			httpd->test_pike_gateway_parse_snapshot(snapshot(
				"userid=xd01hero&character_id=xd01other"));
		};
		conflict_rejected = conflict_err ? 1 : 0;
		check("冲突人物身份和路径穿越标识失败关闭",
			conflict_rejected &&
			!httpd->test_pike_gateway_userid("../xd01hero") &&
			httpd->test_pike_gateway_userid("xd01hero") &&
			httpd->test_pike_gateway_userid("xd01LSQ2026"),
			"客户端可能伪造第二身份绕过账号锁");

		check("Vue和旧JSP注册在建档前解析为同一人物串行锁",
			httpd->test_pike_gateway_registration(
				"login_regnew gamelib xd01newhero pass88 sid challenge")==
					"xd01newhero" &&
			httpd->test_pike_gateway_registration(
				"login_regnew gamelib newhero pass88 sid xd01 key ip ua")==
					"xd01newhero" &&
			httpd->test_pike_gateway_registration("login_regnew bad")=="",
			"并发注册可能绕过人物锁或旧逻辑区前缀被解析错误");

		check("旧JSP失效令牌在离线或迁移后只恢复当前画面",
			source_has(rpc,"stale_command_token_route") &&
			source_has(rpc,"\"command\":\"look\",\"recovered\":1") &&
			source_has(rpc,
				"MAP_WORKERD->query_local_player_epoch(userid)!=epoch") &&
			source_has(rpc,"invalid_command_token_request") &&
			source_has(gateway,"cannot resolve routed command token"),
			"旧页面无法恢复，或畸形/传输错误被错误放行");

		check("只有拍卖命令进入数据库全局锁",
			httpd->test_pike_gateway_auction("vendue 1") &&
			httpd->test_pike_gateway_auction("vendue_ykj2 1") &&
			!httpd->test_pike_gateway_auction("buy 1"),
			"普通命令被全局串行或拍卖跨worker并发");

		check("响应过滤移除跳转头、内部能力和重复长度",
			httpd->test_pike_gateway_header("Content-Type") &&
			!httpd->test_pike_gateway_header("Transfer-Encoding") &&
			!httpd->test_pike_gateway_header("X-Xiand-Request-Accepted") &&
			!httpd->test_pike_gateway_header("Content-Length"),
			"worker可泄露内部围栏或生成冲突HTTP响应");

		check("缺失传输编码头不误报413，真实分块头失败关闭",
			!httpd->test_pike_gateway_transfer_encoding(([])) &&
			!httpd->test_pike_gateway_transfer_encoding(
				(["transfer-encoding":""])) &&
			httpd->test_pike_gateway_transfer_encoding(
				(["transfer-encoding":"chunked"])) &&
			httpd->test_pike_gateway_transfer_encoding(
				(["transfer-encoding":({"chunked"})])),
			"Pike将缺失头强转为字符串0会让所有普通请求返回413");

		mapping cross_before = httpd->test_pike_gateway_migration_plan("w01",
			(["worker_id":"w02","redirect":1]),1);
		mapping cross_after = httpd->test_pike_gateway_migration_plan("w01",
			(["worker_id":"w02","redirect":1]),0);
		mapping same_after = httpd->test_pike_gateway_migration_plan("w01",
			(["worker_id":"w01","redirect":1]),0);
		check("迁移前后只执行一次玩家命令并正确选择到达响应",
			cross_before["deliver"] && !cross_before["replace"] &&
			cross_after["deliver"] && cross_after["replace"] &&
			same_after["deliver"] && same_after["replace"],
			"跨worker移动可能漏到达、双执行或返回旧画面");

		mapping safe_get = httpd->test_pike_gateway_safe_view_request(
			"GET","/api/html?txd=token&cmd=north&cmd=south",
			(["content-type":""]),"");
		mapping safe_json = httpd->test_pike_gateway_safe_view_request(
			"POST","/api/json?userid=xd01hero&cmd=sendother",
			(["content-type":"application/json"]),
			"{\"userid\":\"xd01hero\",\"cmd\":\"trade target\"}");
		mapping safe_form = httpd->test_pike_gateway_safe_view_request(
			"POST","/api?txd=token",
			(["content-type":"application/x-www-form-urlencoded"]),
			"userid=xd01hero&cmd=east&cmd=west");
		mapping safe_json_body = Standards.JSON.decode(
			(string)safe_json["body"]);
		mapping unsupported_view =
			httpd->test_pike_gateway_safe_view_request("GET",
				"/api/autofight_view?txd=token",([]),"");
		check("交接后只用look刷新目标页且不重放原移动交易命令",
			safe_get["path"]=="/api/html?txd=token&cmd=look" &&
			safe_json["path"]==
				"/api/json?userid=xd01hero&cmd=look" &&
			safe_json_body["userid"]=="xd01hero" &&
			safe_json_body["cmd"]=="look" &&
			safe_form["body"]=="userid=xd01hero&cmd=look" &&
			!sizeof(unsupported_view) &&
			source_has(gateway,
				"pike_gateway_deliver_background_arrival(userid,") &&
			source_has(gateway,"\"\",account_id,\"view\"") &&
			!source_has((string)safe_json["body"],"trade target"),
			"目标页可能重复执行方向、交易或其他已经完成的命令");

		mapping arrival_proof = (["ok":1,"userid":"xd01hero",
			"epoch":7,"affinity":"wugongdong",
			"room_path":"/gamelib/d/wugongdong/wugongchao"]);
		check("后台到达用完整可信回执清凭证且拒绝任一字段漂移",
			httpd->test_pike_gateway_arrival_proof(arrival_proof,
				"xd01hero",7,"wugongdong",
				"/gamelib/d/wugongdong/wugongchao") &&
			!httpd->test_pike_gateway_arrival_proof(arrival_proof,
				"xd01other",7,"wugongdong",
				"/gamelib/d/wugongdong/wugongchao") &&
			!httpd->test_pike_gateway_arrival_proof(arrival_proof,
				"xd01hero",8,"wugongdong",
				"/gamelib/d/wugongdong/wugongchao") &&
			source_has(gateway,
				"pike_gateway_acknowledge_arrival_proof(userid,worker_id") &&
			source_has(rpc,"\"epoch\":epoch,\"room_path\":room_path"),
			"重复local_route探针可能在懒加载时超时，或伪回执清除错误epoch");

		check("健康心跳与慢维护分线程且各Worker并行有界探测",
			source_has(gateway,"pike_gateway_monitor_farm = Thread.Farm()") &&
			source_has(gateway,"set_max_num_threads(worker_count)") &&
			source_has(gateway,"pike_gateway_monitor_all_workers()") &&
			source_has(gateway,"pike_gateway_maintenance_loop") &&
			source_has(gateway,
				"pike_gateway_maintenance_thread = Thread.Thread(") &&
			source_has(gateway,
				"pike_gateway_last_monitor_completed_at"),
			"到达重试、社交或在线快照可能串行阻塞全部Worker控制心跳");

		check("并行探测遇到Worker重启时原子发布generation并丢弃旧结果",
			httpd->test_pike_gateway_monitor_generation_current(7,7) &&
			!httpd->test_pike_gateway_monitor_generation_current(7,8) &&
			!httpd->test_pike_gateway_monitor_generation_current(0,0) &&
			source_has(gateway,
				"mapping(string:int) next_generations = ([])") &&
			source_has(gateway,
				"pike_gateway_generations = next_generations") &&
			source_has(gateway,
				"pike_gateway_monitor_generation_current(generation") &&
			source_has(gateway,
				"concurrent successful global recovery supersedes"),
			"旧generation的迟到探测可能把已经恢复的健康Worker再次标成失联");

		check("Gateway嵌入coordinator且不再启动Python常驻进程",
			source_has(daemon,"#include \"_http_api_mod/pike_gateway.pike\"") &&
			source_has(daemon,"call_out(init_pike_gateway, 1)") &&
			source_has(cluster,"wait_for_pike_gateway") &&
			!source_has(cluster,"exec python3 '$ROOT_DIR/tools/map_workers/gateway.py'") &&
			!source_has(cluster,"runtime_process_running gateway"),
			"仍存在第二套Gateway生命周期或启动链未接入Pike");

		check("公网8888与内部18880是同一Pike进程的两个监听器",
			source_has(gateway,"pike_gateway_public_port = Protocols.HTTP.Server.Port") &&
			source_has(gateway,"handle_pike_gateway_request") &&
			source_has(gateway,"pike_gateway_shadow") &&
			source_has(gateway,"isolated-test-server-only"),
			"shadow可能抢占旧书签端口或active绕过试运行门禁");

		check("账号锁、拍卖锁和有界线程池保持因果一致",
			source_has(gateway,"PIKE_GATEWAY_USER_LOCKS = 4096") &&
			source_has(gateway,"pike_gateway_account_management_lock") &&
			source_has(gateway,"pike_gateway_account_resolver_lock") &&
			source_has(gateway,"pike_gateway_account_resolver_daemon") &&
			source_has(gateway,
				"resolver->query_account_id_for_character(userid)") &&
			source_has(gateway,"pike_gateway_auction_lock") &&
			source_has(gateway,"set_max_num_threads") &&
			source_has(gateway,"pike_gateway_pending_requests<pike_gateway_max_requests"),
			"并发量可能无界或共享账号/拍卖发生双写");

		check("placement generation的分配和发布由短控制锁原子排序",
			source_has(gateway,"pike_gateway_assignment_lock") &&
			source_has(gateway,"pike_gateway_assign_affinity") &&
			source_has(gateway,
				"MAP_WORKERD->assign_affinity(affinity,weight,force)") &&
			source_has(gateway,
				"pike_gateway_sync_assignment(affinity,placement)"),
			"并发首次进图可能让较旧generation晚到并误报affinity更新失败");

		check("每个写请求等待worker完成证明，断线后停流盘点",
			source_has(gateway,"X-Xiand-Request-Id") &&
			source_has(gateway,"pike_gateway_wait_for_request_done") &&
			source_has(gateway,"pike_gateway_quarantine_uncertain") &&
			source_has(gateway,"pike_gateway_pause_routing") &&
			source_has(gateway,"pike_gateway_recover_local_players"),
			"响应尾保存未完成就释放账号锁，或不确定请求未隔离");

		check("跨worker交接先保存释放、再提交、最后凭能力到达",
			source_has(gateway,"local_release") &&
			source_has(gateway,"cannot release handoff source: ") &&
			source_has(rpc,"saved = player->save_with_result(0,1)") &&
			source_has(gateway,"commit_handoff") &&
			source_has(gateway,"X-Xiand-Arrival-Room") &&
			source_has(gateway,"pike_gateway_acknowledge_arrival") &&
			source_has(gateway,"dynamic instance cannot cross workers"),
			"装备可能双副本或动态副本被猜测迁移");

		check("已提交到达独立于浏览器接口并可在响应丢失后幂等恢复",
			source_has(gateway,
				"A committed arrival is independent of the current browser endpoint") &&
			source_has(gateway,
				"pike_gateway_deliver_background_arrival(userid,worker_id") &&
			source_has(gateway,"pike_gateway_background_arrivals[userid]") &&
			source_has(gateway,"pike_gateway_set_background_arrival") &&
			source_has(gateway,"pike_gateway_delete_background_arrival") &&
			source_has(gateway,"pike_gateway_background_arrival_snapshot") &&
			source_has(rpc,"local_arrival") &&
			source_has(rpc,"MAP_WORKERD->clear_local_player_arrival(userid)") &&
			source_has(Stdio.read_file(ROOT+
				"/gamelib/single/daemons/http_api_daemon.pike"),
				"saved = player->save_with_result(0,1)") &&
			source_has(user,
				"consume_worker_summon_handoff(void|int worker_fenced_save)") &&
			source_has(user,
				"save_with_result(0,worker_fenced_save)"),
			"状态轮询可能无法装载目标人物，或丢回复后留下永久到达凭证");

		check("慢请求只允许其精确人物完成一次存档，其他写入仍被隔离",
			source_has(user,
				"MAP_WORKERD->local_user_request_save_fence_valid(query_name())") &&
			source_has(Stdio.read_file(ROOT+
				"/gamelib/single/daemons/map_workerd.pike"),
				"(int)request[\"epoch\"]==local_player_epochs[userid]") &&
			source_has(rpc,
				"begin_handoff already froze the exact coordinator epoch") &&
			source_has(rpc,
				"MAP_WORKERD->query_local_player_epoch(userid)!=expected_epoch") &&
			source_has(rpc,"player->retire_worker_copy_after_save"),
			"短控制租约可能中断已接受请求，或放宽成无epoch的任意存档");

		check("安全停机超时覆盖卡住请求且重复停机保持幂等",
			source_has(gateway,"pike_gateway_recovery_lock->trylock()") &&
			source_has(gateway,"pike_gateway_routing_ready = 0") &&
			source_has(gateway,"deadline = time()+30") &&
			source_has(gateway,"pike_gateway_shutdown_prepared") &&
			source_has(gateway,"pike_gateway_recover_local_players();") &&
			source_has(gateway,"retire_abandoned_player_arrival") &&
			source_has(cluster,"pending_reconcile_users") &&
			source_has(cluster,"background_arrivals") &&
			source_has(cluster,"uncertain_requests"),
			"停机可能无限等待、在不确定请求存在时存档或无法安全重试");

		check("故障回退只跳过已摘除节点且仍拒绝未结迁移",
			source_has(gateway,
				"prepare_pike_gateway_failover_shutdown") &&
			source_has(gateway,"failed worker became reachable") &&
			source_has(gateway,"failed_worker_still_reachable") &&
			source_has(gateway,"unlisted unreachable worker") &&
			source_has(gateway,
				"(!failover || (!reconcile && !background))") &&
			source_has(gateway,"if(skipped_workers[worker_id])") &&
			source_has(rpc,"gateway_failover_quiesce") &&
			source_has(cluster,"XIAND_MAP_WORKER_FAILOVER_SHUTDOWN") &&
			source_has(cluster,"failed_worker_csv"),
			"失联节点可能与旧主进程并存，或未结迁移被错误放行");

		check("充值由目标账号锁定并在精确worker幂等存档",
			source_has(gateway,
				"pike_gateway_admin_target(game_command)") &&
			source_has(gateway,"pike_gateway_lock_user_pair") &&
			source_has(gateway,"admin command changed during lock upgrade") &&
			source_has(gateway,"pike_gateway_resolve_routed_command") &&
			source_has(rpc,"local_resolve_command") &&
			source_has(rpc,"unhide_command(userid,command)") &&
			source_has(rpc,"local_admin_recharge") &&
			source_has(rpc,
				"target_worker==MAP_WORKERD->query_local_worker_id()") &&
			source_has(rpc,
				"execute_map_worker_local_admin_recharge(target_payload)") &&
			source_has(rpc,
				"execute_map_worker_local_account_refresh(") &&
			source_has(rpc,"local_account_refresh") &&
			source_has(user,"admin_recharge_bonus_receipts") &&
			source_has(Stdio.read_file(ROOT+"/gamelib/cmds/txadd.pike"),
				"give_recharge_bonus_once"),
			"管理进程可能复制目标人物、重复附赠或保留跨worker旧钱包缓存");

		check("后台物品发放与充值共享双账号锁且使用独立能力凭据",
			source_has(gateway,"pike_gateway_admin_item_grant_target") &&
			source_has(gateway,"admin_item_grant|") &&
			source_has(gateway,"X-Xiand-Admin-Item-Request") &&
			source_has(rpc,"execute_map_worker_admin_item_grant") &&
			source_has(rpc,"local_admin_item_grant") &&
			source_has(map_worker_daemon,"admin_item_request_id") &&
			source_has(user,"admin_item_grant_receipts"),
			"后台发物可能路由到错误worker或在超时重试时克隆物品");

		check("在线列表聚合后逐人物核对worker与epoch并拒绝重复owner",
			source_has(gateway,"query_pike_gateway_online_users") &&
			source_has(gateway,"duplicate_online_owner") &&
			source_has(gateway,"online_route_mismatch") &&
			source_has(rpc,"local_online_users") &&
			source_has(rpc,"query_local_online_snapshot") &&
			source_has(gateway,"pike_gateway_online_rows_by_worker") &&
			source_has(gateway,"XIAND_WORKER_CONTROL_TIMEOUT"),
			"在线人数可能重复、漏算或接受失效worker快照");

		int control_heartbeat = search(gateway,
			"\"local_control_heartbeat\",([])");
		int live_renewal = search(gateway,
			"pike_gateway_renew_live_player_leases(worker_id,generation)",
			control_heartbeat);
		check("监控先续worker控制租约再分页续人物租约",
			control_heartbeat!=-1 && live_renewal>control_heartbeat &&
			source_has(gateway,"pike_gateway_worker_is_reachable") &&
			source_has(gateway,"pike_gateway_set_worker_reachable") &&
			source_has(gateway,
				"if(has_prefix(pike_gateway_last_error,prefix))"),
			"慢请求可能耗尽控制窗口并在健康监控中误隔离worker");

		check("在线快照只在完整监控轮次后一次性发布到全部worker",
			source_has(gateway,"pike_gateway_publish_online_snapshot") &&
			source_has(gateway,"local_online_snapshot_update") &&
			source_has(rpc,"update_local_online_snapshot") &&
			source_has(gateway,"pike_gateway_publish_online_snapshot();"),
			"逐worker边采集边发布会在人物迁移时显示重复或离线状态");

		check("跨worker私聊和世界广播由gateway异步投递且幂等确认",
			source_has(rpc,"local_social_events") &&
			source_has(rpc,"local_social_apply") &&
			source_has(rpc,"local_social_ack") &&
			source_has(rpc,"target_request_running") &&
			source_has(rpc,"begin_local_social_delivery(event_id,0)") &&
			source_has(gateway,"pike_gateway_run_social_events") &&
			source_has(gateway,"pike_gateway_social_lock->trylock()") &&
			source_has(gateway,"if(worker_id==source_worker)") &&
			source_has(gateway,"private tell target is unavailable") &&
			source_has(Stdio.read_file(ROOT+"/gamelib/cmds/tell.pike"),
				"stage_local_social_event(") &&
			source_has(Stdio.read_file(ROOT+
				"/gamelib/single/daemons/broadcastd.pike"),
				"apply_distributed_broadcast") &&
			source_has(rpc,"\"race_id\":(string)player->query_raceId()"),
			"私聊可能在目标命令中并发改档，或广播重试造成重复显示/重复扣符");

		string term_ok = Stdio.read_file(ROOT+"/gamelib/cmds/term_ok.pike");
		string termd = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/termd.pike");
		string map_workerd = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/map_workerd.pike");
		check("跨worker队伍结构命令全局串行且同步窗口保留有效邀请",
			source_has(gateway,"pike_gateway_team_mutation_lock") &&
			source_has(gateway,"pike_gateway_team_mutation_command") &&
			source_has(gateway,"pike_gateway_run_social_events(1)") &&
			source_has(gateway,"Finish any earlier membership snapshot") &&
			source_has(gateway,"Publish this mutation to every worker") &&
			source_has(term_ok,"队伍状态正在跨地图同步") &&
			source_has(term_ok,"!TERMD->query_termId(remote_team_id)") &&
			source_has(rpc,"team_member_request_running"),
			"并发入队可能丢成员，或快照尚未到达时永久清除仍有效邀请");

		check("队伍快照先于通知发布且无本地成员worker幂等忽略",
			source_has(termd,"local_worker_has_team_player") &&
			source_has(termd,"team_snapshot_missing") &&
			source_has(termd,"no_local_team_member") &&
			source_has(map_workerd,"local_team_player_exists") &&
			source_has(map_workerd,"indices(local_player_epochs)") &&
			source_has(termd,"\t\tpublish_distributed_team_snapshot(tid,uid);\n"+
				"\t\tterm_tell(tid,msg);") &&
			source_has(gateway,"team sync delivery rejected worker=") &&
			source_has(gateway,"\" kind=\"+kind+\" code=\"+code"),
			"空闲worker会使队伍通知永久重试，或通知抢在快照前到达");

		check("付费世界广播与社交事件先持久化且重启后保持幂等",
			source_has(map_workerd,"persist_local_social_outbox_unlocked") &&
			source_has(map_workerd,"restore_local_social_outbox") &&
			source_has(map_workerd,"local_social_kind_is_durable") &&
			source_has(map_workerd,"kind==\"team_snapshot\"") &&
			source_has(map_workerd,"kind==\"team_invite\"") &&
			source_has(map_workerd,"restore_local_team_outbox_snapshots") &&
			source_has(map_workerd,"local_social_persist_failed") &&
			source_has(map_workerd,"complete_local_social_delivery") &&
			source_has(map_workerd,"social_delivery_markers") &&
			source_has(map_workerd,"MAP_WORKER_LOCAL_BROADCAST_TTL") &&
			source_has(rpc,"social_delivery_persist_failed") &&
			source_has(rpc,"complete_local_social_delivery(event_id,1)"),
			"worker崩溃窗口可能吞掉已扣传音符，或重启重放造成重复广播");

		check("人物首次登录不会在每个worker重复启动全局daemon和技能",
			source_has(game_master,
				"node_role==\"gateway\" || node_role==\"worker\"") &&
			source_has(game_master,
				"Map-worker node skipping eager daemon") &&
			source_has(game_master,"if(!map_worker_node)") &&
			source_has(game_master,"gamelib/single/skills"),
			"第二层master会绕过启动边界，复制家园/拍卖定时器并阻塞首次look");

		check("家园全局快照和推荐店铺定时器只由home owner worker执行",
			source_has(homed,"home_persistence_owner()") &&
			source_has(homed,"local_worker_owns_room") &&
			source_has(homed,
				"persistence belongs to home owner worker") &&
			source_has(homed,"if(!home_persistence_owner())"),
			"多个worker可能同时覆盖家园快照或重复处理推荐店铺到期");

		check("恢复先查未完成请求并丢弃重复内存副本而不保存",
			source_has(gateway,"local_inflight") &&
			source_has(gateway,"local_inventory") &&
			source_has(gateway,"local_discard") &&
			source_has(gateway,"pike_gateway_prune_reconciled_tombstones") &&
			source_has(gateway,"local_control_resume"),
			"宕机恢复可能覆盖正确人物档案或过早恢复worker写权限");

		check("内部状态公开给健康检查且公网拒绝internal路径",
			source_has(rpc,"case \"gateway_status\"") &&
			source_has(rpc,"result[\"gateway\"] = query_pike_gateway_status()") &&
			source_has(gateway,"has_prefix(path_only,\"/internal/\")") &&
			source_has(cluster,"embedded Pike gateway controller is not ready"),
			"健康检查可能假阳性或公网暴露控制面");
	};
	if(err){
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
		check("测试运行时无异常",0,error_desc);
	}
	werror("\nPike Gateway测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
