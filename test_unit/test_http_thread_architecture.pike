#!/usr/bin/env pike
/**
 * HTTP API 多线程与事件队列回归测试。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total":0,
	"passed":0,
	"failed":0,
]);

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
	int valid = canonical && legacy && canonical == legacy &&
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
		status["cross_user_policy"] == "parallel_except_core" &&
		(int)status["user_command_locks"] >= 1;
	test_result("同账号稳定复用命令锁且不同账号保留并行",valid,
		"账号规范化、锁复用或线程策略状态错误");
}

void test_core_command_coverage(object httpd)
{
	int valid = httpd->is_core_command("buy_items book fangshi") == 1 &&
		httpd->is_core_command("vendue_buy_now 1") == 1 &&
		httpd->is_core_command("term_future_action") == 1 &&
		httpd->is_core_command("viceskill_dig ore 0") == 1 &&
		httpd->is_core_command("flushview") == 1 &&
		httpd->is_core_command("use_perform yueji") == 1 &&
		httpd->is_core_command("mail_send_confirm user") == 1 &&
		httpd->is_core_command("home_buy_shopItem_confirm user") == 1 &&
		httpd->is_core_command("bang_accept user") == 1 &&
		httpd->is_core_command("sendother_ok user") == 1 &&
		httpd->is_core_command("trade_daoju user") == 1 &&
		httpd->is_core_command("game_deal manager_user_online") == 1 &&
		httpd->is_core_command("look") == 0;
	test_result("购买、拍卖、社交、家园和跨档案命令进入核心锁",valid,
		"核心命令或前缀覆盖不完整");
}

void test_timeout_and_observability_source(object httpd)
{
	string thread_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/thread_manager.pike");
	string daemon_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	int worker_start = search(thread_source,"void _execute_in_thread");
	int core_start = search(thread_source,"string execute_core_command");
	string worker_source = "";
	if(worker_start >= 0 && core_start > worker_start)
		worker_source = thread_source[worker_start..core_start-1];
	mapping performance = httpd->query_http_performance_status();
	int valid = thread_source && daemon_source &&
		search(thread_source,"deadline = time()+HTTP_COMMAND_TIMEOUT") != -1 &&
		search(thread_source,"remaining > 0") != -1 &&
		search(worker_source,"user_key = user_mutex->lock()") != -1 &&
		search(worker_source,"destruct(user_key)") != -1 &&
		search(daemon_source,"record_http_request_timing") != -1 &&
		search(daemon_source,"\"dispatch_mode\":queue_status") != -1 &&
		mappingp(performance) && performance["slow_threshold_ms"] == 2000;
	test_result("超时后台线程保留账号锁且健康检查包含性能指标",valid,
		"超时可能提前释放账号锁、无限等待或运行态观测接线缺失");
}

void test_bounded_parallel_workers(object httpd)
{
	string source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/thread_manager.pike");
	mapping status = httpd->query_thread_status();
	int valid = source && mappingp(status) &&
		(int)status["parallel_worker_limit"] == 16 &&
		(int)status["parallel_workers_active"] >= 0 &&
		(int)status["parallel_workers_active"] <= 16 &&
		search(source,"if(!acquire_parallel_worker_slot())") != -1 &&
		search(source,"parallel_workers_rejected++") != -1 &&
		search(source,"record_parallel_worker_timeout()") != -1 &&
		search(source,"sizeof(cmd) > 2048") != -1;
	test_result("普通命令线程有界、超载快速失败且指标可观测",valid,
		"普通请求仍可能无限建线程，或缺少过载与超时指标");
}

void test_thread_slot_release_on_all_paths(object httpd)
{
	string canonical = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/thread_manager.pike");
	string legacy = Stdio.read_file(ROOT+
		"/gamelib/single/d/http_api/thread_manager.pike");
	int worker_start = search(canonical,"void _execute_in_thread");
	int core_start = search(canonical,"string execute_core_command");
	string worker_source = "";
	if(worker_start>=0 && core_start>worker_start)
		worker_source = canonical[worker_start..core_start-1];
	int valid = canonical && legacy && canonical==legacy &&
		search(worker_source,"mixed result_err = catch")!=-1 &&
		search(worker_source,"release_parallel_worker_slot(1)")!=-1 &&
		search(worker_source,"if(user_key)")!=-1 &&
		search(canonical,"sizeof(userid) > 64")!=-1 &&
		search(canonical,"sizeof(password || \"\") > 128")!=-1;
	test_result("异常发布、锁获取和超长输入均不会泄漏线程槽",valid,
		"结果发布或锁异常仍可能泄漏线程容量，或双目录漂移");
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
		search(renderer,"query_buff(\"team_guard\", 1)")!=-1;
	test_result("战斗秒级轮询不刷成功日志且返回镇岳护盾状态",valid,
		"战斗状态轮询仍有高频磁盘I/O或护盾不可观测");
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
		test_core_command_coverage(httpd);
		test_timeout_and_observability_source(httpd);
		test_bounded_parallel_workers(httpd);
		test_thread_slot_release_on_all_paths(httpd);
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
