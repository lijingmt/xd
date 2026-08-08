#!/usr/bin/env pike
/** HTTP API 核心串行、非核心并行与线程隔离回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total":0,
	"passed":0,
	"failed":0,
]);

class ThreadPlayerProbe {}

void run_thread_local_probe(object connd,object worker_player,
	mapping result)
{
	connd->set_this_player(worker_player);
	result["worker_ok"] = connd->query_this_player()==worker_player;
}

void run_non_backend_world_probe(object httpd)
{
	httpd->route_and_execute("__testunit_thread_probe__","","attack target");
}

void record_world_queue_probe(string output,mapping result,string key)
{
	result[key] = (int)result[key]+1;
}

void test_result(string name,int passed,string reason)
{
	test_results["total"]++;
	werror("\n[HTTP线程架构 %d] %s\n",test_results["total"],name);
	if(passed){
		test_results["passed"]++;
		werror("  ✓ 通过\n");
	}
	else{
		test_results["failed"]++;
		werror("  ✗ 失败: %s\n",reason);
	}
}

void test_event_driven_queue_source()
{
	string canonical = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/command_queue.pike");
	string legacy = Stdio.read_file(ROOT+
		"/gamelib/single/d/http_api/command_queue.pike");
	string daemon_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	int valid = canonical && legacy &&
		search(legacy,"_http_api_mod/command_queue.pike")!=-1 &&
		search(canonical,"user_request_queues[userid] = queue") != -1 &&
		search(canonical,"dispatch_mode\"] = \"event_driven\"") != -1 &&
		search(canonical,
			"call_out(process_user_queues, interval / 1000)") == -1 &&
		daemon_source && search(daemon_source,
			"call_out(cleanup_old_results, RESULT_CLEANUP_INTERVAL)") != -1 &&
		search(daemon_source,"QUEUE_CHECK_INTERVAL / 1000") == -1;
	test_result("事件驱动队列替代0秒轮询且双目录一致",valid,
		"队列仍可能漏入队、空转或两份实现漂移");
}

void test_queue_runtime_contract(object httpd)
{
	string userid = "__testunit_http_queue__";
	string request_id = userid+"_"+(string)time();
	string result_id = request_id+"_result";
	int result_count_before = httpd->query_request_result_count();
	int enqueued = httpd->enqueue_user_request(userid,"look",request_id);
	int queue_size = httpd->query_user_request_queue_size(userid);
	httpd->remove_user_request_queue(userid);
	httpd->store_request_result(result_id,"queue-ok");
	string|zero stored = httpd->get_request_result(result_id);
	int result_count_after = httpd->query_request_result_count();
	int valid = enqueued == 1 && queue_size == 1 &&
		httpd->query_user_request_queue_size(userid) == 0 &&
		stored == "queue-ok" && result_count_after == result_count_before;
	test_result("运行时入队、移除与结果缓存清理闭环",valid,
		"入队数组未持久化或结果缓存留下空键");
}

void test_same_user_serialization(object httpd)
{
	object first = httpd->query_user_command_mutex("XD01ThreadUser");
	object second = httpd->query_user_command_mutex(" xd01threaduser ");
	mapping status = httpd->query_thread_status();
	int valid = first && first == second &&
		status["same_user_policy"] == "serialized" &&
		status["cross_user_policy"] ==
			"round_robin_world_parallel_render" &&
		status["process_model"] == "single_process" &&
		(int)status["user_command_locks"] >= 1;
	test_result("同账号串行且不同账号世界命令公平轮转",valid,
		"账号规范化、锁复用或跨账号并行策略状态错误");
}

void test_world_queue_coalescing_and_causal_order(object httpd)
{
	string userid = "XD01TestUnitWorldQueue";
	mapping callback_result = ([]);
	mapping before = httpd->query_thread_status();
	int first = httpd->enqueue_world_command(userid,"","flushview",
		record_world_queue_probe,({callback_result,"first"}));
	int merged = httpd->enqueue_world_command(
		lower_case(userid),"","flushview",record_world_queue_probe,
		({callback_result,"merged"}));
	int merged_size = httpd->query_world_user_queue_size(userid);
	int middle = httpd->enqueue_world_command(userid,"","look",
		record_world_queue_probe,({callback_result,"middle"}));
	int trailing = httpd->enqueue_world_command(userid,"","flushview",
		record_world_queue_probe,({callback_result,"trailing"}));
	int ordered_size = httpd->query_world_user_queue_size(userid);
	httpd->remove_world_user_queue(lower_case(userid));
	int look_first = httpd->enqueue_world_command(userid,"","look",
		record_world_queue_probe,({callback_result,"look_first"}));
	int look_merged = httpd->enqueue_world_command(userid,"","look",
		record_world_queue_probe,({callback_result,"look_merged"}));
	int look_size = httpd->query_world_user_queue_size(userid);
	httpd->remove_world_user_queue(userid);
	mapping after = httpd->query_thread_status();
	int valid = first==1 && merged==1 && middle==1 && trailing==1 &&
		look_first==1 && look_merged==1 && look_size==1 &&
		merged_size==1 && ordered_size==3 &&
		httpd->query_world_user_queue_size(userid)==0 &&
		(int)after["world_pending_commands"]==
			(int)before["world_pending_commands"] &&
		(int)after["world_pending_callbacks"]==
			(int)before["world_pending_callbacks"] &&
		(int)after["world_coalesced_refreshes"]==
			(int)before["world_coalesced_refreshes"]+1 &&
		(int)after["world_coalesced_looks"]==
			(int)before["world_coalesced_looks"]+1;
	test_result("重复刷新/查看只在队尾合并且不跨越中间命令",valid,
		"刷新合并破坏命令因果顺序、账号规范化或清理计数错误");
}

void test_non_backend_world_rejection(object httpd)
{
	mapping before = httpd->query_thread_status();
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		object worker = Thread.Thread(run_non_backend_world_probe,httpd);
		worker->wait();
		mapping after = httpd->query_thread_status();
		valid = (int)after["non_backend_rejected"] ==
			(int)before["non_backend_rejected"]+1 &&
			(int)after["world_command_count"] ==
			(int)before["world_command_count"];
	};
	if(err)
		error_desc = describe_error(err);
	test_result("工作线程核心命令被门禁拒绝且不触碰世界状态",
		!err && valid,"非Backend线程仍可能写游戏对象: "+error_desc);
}

void test_core_command_coverage(object httpd)
{
	int valid = httpd->is_core_command("buy_items book fangshi") == 1 &&
		httpd->is_core_command("choice_race third") == 1 &&
		httpd->is_core_command("choice_profe third/fangshi") == 1 &&
		httpd->is_core_command("start third") == 1 &&
		httpd->is_core_command("vendue_buy_now 1") == 1 &&
		httpd->is_core_command("term_future_action") == 1 &&
		httpd->is_core_command("viceskill_dig ore 0") == 1 &&
		httpd->is_core_command("artisan deposit") == 1 &&
		httpd->is_core_command("artisan_master_craft duanzao 120") == 1 &&
		httpd->is_core_command("flushview") == 1 &&
		httpd->is_core_command("use_perform yueji") == 0 &&
		httpd->is_core_command("mail_send_confirm user") == 1 &&
		httpd->is_core_command("home_buy_shopItem_confirm user") == 1 &&
		httpd->is_core_command("bang_accept user") == 1 &&
		httpd->is_core_command("sendother_ok user") == 1 &&
		httpd->is_core_command("trade_daoju user") == 1 &&
		httpd->is_core_command("chatroom_chat hello") == 1 &&
		httpd->is_core_command("lottery_join_in 1") == 1 &&
		httpd->is_core_command("transfer_to player") == 1 &&
		httpd->is_core_command("qge74hye congxianzhen/road") == 1 &&
		httpd->is_core_command("use_toolbar 0") == 1 &&
		httpd->is_core_command("shutdown_safe") == 1 &&
		httpd->is_core_command("game_deal manager_user_online") == 1 &&
		httpd->is_core_command("look") == 0 &&
		httpd->is_core_command("score") == 0 &&
		httpd->is_core_command("paihang_list mark 1") == 0;
	test_result("人物初始化、购买、拍卖、社交、家园和跨档案命令进入核心锁",valid,
		"核心命令或前缀覆盖不完整");
}

void test_timeout_and_observability_source(object httpd)
{
	string thread_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/thread_manager.pike");
	string daemon_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string renderer_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/html_renderer.pike");
	mapping performance = httpd->query_http_performance_status();
	mapping runtime = query_runtime_performance();
	int valid = thread_source && daemon_source && renderer_source &&
		search(thread_source,"Thread.Thread(") == -1 &&
		search(thread_source,"string execute_core_command") != -1 &&
		search(thread_source,"Thread.Farm()") != -1 &&
		search(thread_source,"parallel_command_farm_init_lock") != -1 &&
		search(thread_source,"execute_parallel_command_job") == -1 &&
		search(renderer_source,"button_grade_snapshot") != -1 &&
		search(renderer_source,"refresh_button_grade_snapshot") != -1 &&
		search(renderer_source,"object topten = find_object(ROOT +") == -1 &&
		search(thread_source,"execute_parallel_json_job") != -1 &&
		search(thread_source,"enqueue_world_command") != -1 &&
		search(thread_source,"call_out(process_world_command_queue,0)") != -1 &&
		search(thread_source,"core_key = core_lock->lock()") != -1 &&
		search(thread_source,
			"master()->backend_thread()!=this_thread()") != -1 &&
		search(thread_source,"destruct(core_key)") != -1 &&
		search(thread_source,"describe_backtrace(err)") != -1 &&
		search(thread_source,"record_world_command_finish") != -1 &&
		search(daemon_source,"record_http_request_timing") != -1 &&
		search(daemon_source,"\"dispatch_mode\":queue_status") != -1 &&
		mappingp(performance) && performance["slow_threshold_ms"] == 2000 &&
		mappingp(runtime) && runtime["process_model"]=="single_process";
	test_result("世界命令Backend门禁和并行响应池均可观测",valid,
		"仍在按请求建线程、核心门禁错误或观测接线缺失");
}

void test_bounded_parallel_workers(object httpd)
{
	string source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/async_iod.pike");
	object async_io = (object)(ROOT+
		"/gamelib/single/daemons/async_iod.pike");
	mapping status = httpd->query_thread_status();
	mapping io_status = async_io->query_status();
	int valid = source && mappingp(status) && mappingp(io_status) &&
		status["mode"]=="deferred_world_parallel_render" &&
		(int)status["parallel_thread_limit"]==16 &&
		(int)status["parallel_pending_limit"]==128 &&
		(int)status["world_pending_limit"]==512 &&
		(int)status["world_per_user_limit"]==8 &&
		(int)status["parallel_pending"]>=0 &&
		io_status["mode"]=="Thread.Farm" &&
		(int)io_status["thread_limit"] == 8 &&
		(int)io_status["read_thread_limit"] == 7 &&
		(int)io_status["append_thread_limit"] == 1 &&
		(int)io_status["pending_limit"] == 2048 &&
		(int)io_status["pending_jobs"] >= 0 &&
		search(source,"Thread.Farm()") != -1 &&
		search(source,"future->on_success(callback,@extra)") != -1 &&
		search(source,"run_async(append_text_job") != -1 &&
		search(source,"pending_jobs < ASYNC_IO_PENDING_LIMIT") != -1 &&
		search(source,"ASYNC_IO_APPEND_THREAD_LIMIT 1") != -1;
	test_result("纯响应与I/O均使用有界Pike 9 Thread.Farm",valid,
		"线程池无界、未复用或运行指标缺失");
}

void test_thread_slot_release_on_all_paths(object httpd)
{
	string canonical = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/thread_manager.pike");
	string legacy = Stdio.read_file(ROOT+
		"/gamelib/single/d/http_api/thread_manager.pike");
	int valid = canonical && legacy &&
		search(legacy,
			"../../daemons/_http_api_mod/thread_manager.pike")!=-1 &&
		search(canonical,"Thread.Thread(")==-1 &&
		search(canonical,"HTTP_PARALLEL_PENDING_LIMIT = 128")!=-1 &&
		search(canonical,"HTTP_WORLD_PENDING_LIMIT = 512")!=-1 &&
		search(canonical,"HTTP_WORLD_PER_USER_LIMIT = 8")!=-1 &&
		search(canonical,"reserve_parallel_command()")!=-1 &&
		search(canonical,"cancel_parallel_command()")!=-1 &&
		search(canonical,"if(core_key)")!=-1 &&
		search(canonical,"if(user_key)")!=-1 &&
		search(canonical,"world_commands_waiting--")!=-1 &&
		search(canonical,"sizeof(userid)>64")!=-1 &&
		search(canonical,"sizeof(password || \"\")>128")!=-1 &&
		search(canonical,"sizeof(queue)>=HTTP_WORLD_PER_USER_LIMIT")!=-1;
	test_result("异常、锁获取和超长输入均不会泄漏写入队列",valid,
		"异常路径可能泄漏计数、输入无界或兼容入口漂移");
}

void test_thread_local_player_and_connection_lock()
{
	string connd = Stdio.read_file(ROOT+"/lowlib/connd.pike");
	string virtual_conn = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/virtual_conn.pike");
	object connd_daemon = (object)(SROOT+"/connd.pike");
	object original = connd_daemon->query_this_player();
	object main_player = ThreadPlayerProbe();
	object worker_player = ThreadPlayerProbe();
	mapping probe_result = ([]);
	connd_daemon->set_this_player(main_player);
	object worker = Thread.Thread(run_thread_local_probe,connd_daemon,
		worker_player,probe_result);
	worker->wait();
	int runtime_isolated = probe_result["worker_ok"] &&
		connd_daemon->query_this_player()==main_player;
	connd_daemon->set_this_player(original);
	int valid = connd && virtual_conn && runtime_isolated &&
		search(connd,"Thread.Local thread_this_player")!=-1 &&
		search(connd,"thread_this_player->set(user)")!=-1 &&
		search(connd,"thread_this_player->get()")!=-1 &&
		search(connd,"Thread.Mutex connection_lock")!=-1 &&
		search(virtual_conn,"Thread.Mutex vconnections_lock")!=-1 &&
		search(virtual_conn,"claim_idle_connection")!=-1;
	test_result("this_player线程本地化且连接表短锁保护",valid,
		"并行命令可能串人物、串输出或与空闲清理竞争");
}

void test_async_http_command_routes()
{
	string daemon = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string queue = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/command_queue.pike");
	int valid = daemon && queue &&
		search(daemon,"finish_handle_api_json")!=-1 &&
		search(daemon,"command_response==\"命令执行错误\"")!=-1 &&
		search(daemon,"游戏命令执行失败，请重试")!=-1 &&
		search(daemon,"finish_handle_api_html")!=-1 &&
		search(daemon,"finish_handle_api_performs")!=-1 &&
		search(daemon,
			"execute_command_async(auth_userid,auth_password,actual_cmd")!=-1 &&
		search(queue,"execute_command_async(userid,\"\",cmd")!=-1 &&
		search(queue,"finish_queued_command")!=-1;
	test_result("主要HTTP命令接口异步入池且由Backend回调响应",valid,
		"HTTP事件线程仍可能等待非核心命令完成");
}

void test_registry_cleanup_contract(object httpd)
{
	string rate_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/rate_limit.pike");
	string rate_legacy = Stdio.read_file(ROOT+
		"/gamelib/single/d/http_api/rate_limit.pike");
	string conn_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/virtual_conn.pike");
	int valid = rate_source && rate_legacy && rate_source==rate_legacy &&
		search(rate_source,"rate_limits[ip] = 0")==-1 &&
		search(rate_source,"banned_ips[ip] = 0")==-1 &&
		search(rate_source,"m_delete(rate_limits,ip)")!=-1 &&
		conn_source &&
		search(conn_source,"[IDLE_CHECK] Running cleanup")==-1 &&
		search(conn_source,"[IDLE_CHECK] User")==-1 &&
		search(conn_source,"vconnections[userid] = 0")==-1 &&
		search(conn_source,"m_delete(vconnections,userid)")!=-1;
	test_result("过期IP/连接真正删除且空闲扫描不再逐连接刷日志",valid,
		"守护映射仍会留下空键或每分钟产生无意义日志");
}

void test_http_input_boundaries()
{
	string config = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/config.pike");
	string daemon = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string utils = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/utils.pike");
	int handle_start = search(daemon,
		"void handle_request(Protocols.HTTP.Server.Request req)");
	string handle_source = handle_start>=0 ? daemon[handle_start..] : "";
	int catch_start = search(handle_source,"mixed err = catch");
	int options_start = search(handle_source,"if(method == \"OPTIONS\")");
	int valid = config && daemon && utils &&
		search(config,"MAX_HTTP_QUERY_SIZE = 8192")!=-1 &&
		search(config,"MAX_HTTP_BODY_SIZE = 65536")!=-1 &&
		search(daemon,"sizeof(req->body_raw)>MAX_HTTP_BODY_SIZE")!=-1 &&
		search(daemon,"Request too large")!=-1 &&
		options_start!=-1 && options_start<catch_start &&
		search(utils,"search(path,\"..\")!=-1")!=-1 &&
		search(utils,"Invalid static path")!=-1;
	test_result("HTTP查询/正文/静态路径有界且预检不在catch内返回",valid,
		"超大请求、目录穿越或catch内提前返回仍未防护");
}

void test_battle_poll_efficiency()
{
	string daemon = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string renderer = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/html_renderer.pike");
	int valid = daemon && renderer &&
		search(daemon," Enemy %s HP:")==-1 &&
		search(renderer,"result[\"guard_active\"]")!=-1 &&
		search(renderer,"query_buff(\"team_guard\", 1)")!=-1 &&
		search(renderer,"result[\"star_marks\"]")!=-1 &&
		search(renderer,"query_tianxiang_star_marks")!=-1 &&
		search(renderer,"result[\"medicine_pacts\"]")!=-1 &&
		search(renderer,"query_lingyi_medicine_pacts")!=-1 &&
		search(renderer,"result[\"lingyi_revive\"]")!=-1 &&
		search(renderer,"query_lingyi_auto_revive_status")!=-1 &&
		search(renderer,"result[\"recent_aoe_report\"]")!=-1 &&
		search(renderer,"query_recent_aoe_battle_report")!=-1 &&
		search(daemon,"case \"/api/autofight_view\"")!=-1 &&
		search(daemon,"build_autofight_view_json_job")!=-1 &&
		search(daemon,"query_autofight_refresh_snapshot")!=-1;
	test_result("战斗秒级轮询不刷成功日志且返回镇越护盾/天象星痕/灵医药契与复苏群攻状态",valid,
		"战斗状态轮询仍有高频磁盘I/O或职业资源不可观测");
}

int main()
{
	object httpd = (object)(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string error_desc = "";

	werror("\n========== HTTP API线程架构测试 ==========\n");
	mixed err = catch {
		test_event_driven_queue_source();
		test_queue_runtime_contract(httpd);
		test_same_user_serialization(httpd);
		test_world_queue_coalescing_and_causal_order(httpd);
		test_non_backend_world_rejection(httpd);
		test_core_command_coverage(httpd);
		test_timeout_and_observability_source(httpd);
		test_bounded_parallel_workers(httpd);
		test_thread_slot_release_on_all_paths(httpd);
		test_thread_local_player_and_connection_lock();
		test_async_http_command_routes();
		test_registry_cleanup_contract(httpd);
		test_http_input_boundaries();
		test_battle_poll_efficiency();
	};
	if(err){
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
		test_result("测试运行时无异常",0,error_desc);
	}
	werror("\nHTTP线程架构测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"] == 0 ? 0 : 1;
}
