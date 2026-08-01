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
		httpd->is_core_command("look") == 0;
	test_result("购买、拍卖、组队和采集共享命令进入核心锁",valid,
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
