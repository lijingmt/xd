#!/usr/bin/env pike

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int ok,string reason)
{
	results["total"]++;
	werror("\n[单进程优化 %d] %s\n",results["total"],name);
	if(ok){
		results["passed"]++;
		werror("  ✓ 通过\n");
	}
	else{
		results["failed"]++;
		werror("  ✗ 失败: %s\n",reason);
	}
}

void test_thread_farm_io()
{
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/async_iod.pike");
	string source = daemon->read_text(ROOT+
		"/gamelib/data/task/task_list.csv",4*1024*1024);
	string static_source = daemon->read_text(ROOT+
		"/web/web_vue/index.html",4*1024*1024);
	int accepted = daemon->append_log(ROOT+
		"/log/testunit_async_io.log",
		ctime(time())+" Thread.Farm async append accepted\n");
	mapping status = daemon->query_status();
	check("Thread.Farm可读配置并有界接收异步日志",
		source && sizeof(source)>0 && static_source &&
		sizeof(static_source)>0 && accepted==1 &&
		status["mode"]=="Thread.Farm" &&
		(int)status["thread_limit"]==8 &&
		(int)status["read_thread_limit"]==7 &&
		(int)status["append_thread_limit"]==1 &&
		(int)status["pending_jobs"]<=(int)status["pending_limit"],
		"线程池读取、队列上限或运行态统计异常");
}

void test_parallel_command_source()
{
	string source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/thread_manager.pike");
	check("核心命令串行且非核心命令进入有界线程池",
		source && search(source,"Thread.Thread(")==-1 &&
		search(source,"Thread.Farm()")!=-1 &&
		search(source,"HTTP_PARALLEL_THREAD_LIMIT = 16")!=-1 &&
		search(source,"execute_parallel_command_job")!=-1 &&
		search(source,"core_key = core_lock->lock()")!=-1 &&
		search(source,"execute_world_command_sync")==-1 &&
		search(source,"execute_command_sync(userid,password,cmd)")!=-1,
		"仍有临时线程、核心锁漂移或并行池未接线");
}

void test_heartbeat_budget_and_metrics()
{
	string source = Stdio.read_file(ROOT+"/lowlib/efuns.pike");
	mapping status = query_runtime_performance();
	check("心跳按对象数和耗时预算分片且容量阈值可观测",
		source &&
		search(source,"HEART_BEAT_SLICE_MAX_OBJECTS 128")!=-1 &&
		search(source,"HEART_BEAT_SLICE_BUDGET_US 5000")!=-1 &&
		search(source,"call_out(heart_beat_slice,0)")!=-1 &&
		search(source,"System.getrusage()")!=-1 &&
		mappingp(status) && status["process_model"]=="single_process" &&
		(int)status["heartbeat_object_budget"]==128 &&
		(int)status["cpu_warning_percent"]==70,
		"心跳仍整批执行，或Backend/CPU阈值指标未接线");
}

void test_save_and_cache_metrics()
{
	string save_source = Stdio.read_file(ROOT+
		"/lowlib/system/inherit/feature/save.pike");
	object autofightd = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	mapping route_cache = autofightd->query_training_route_cache_status();
	mapping task_cache = TASKD->query_cache_status();
	mapping map_cache = MAPD->query_cache_status();
	mapping skill_cache = MUD_SKILLSD->query_cache_status();
	check("存档耗时与地图任务技能路线缓存均可观测",
		save_source && search(save_source,"record_save_timing(")!=-1 &&
		route_cache["mode"]=="immutable_snapshot" &&
		(int)route_cache["human"]==69 &&
		(int)route_cache["monst"]==69 &&
		(int)route_cache["third"]==69 &&
		(int)task_cache["tasks"]>0 &&
		(int)map_cache["rooms"]>0 &&
		(int)skill_cache["skills"]>0,
		"存档指标或常驻配置索引未建立");
}

void test_afk_scan_budget_and_auth_boundary()
{
	string source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object httpd = (object)(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	mapping afk = ((object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike"))->
		query_autofight_performance_status();
	check("挂机扫描有轮转预算且认证路径拒绝目录穿越",
		source && search(source,"AUTOFIGHT_SCAN_MAX_OBJECTS 128")!=-1 &&
		search(source,"/tmp/autofight_scan_cursor")!=-1 &&
		search(source,"query_bounded_scan_slice")!=-1 &&
		search(source,"\"cycle_complete\"")!=-1 &&
		(int)afk["scan_object_budget"]==128 &&
		httpd->get_user_password("../etc/passwd")==0,
		"挂机大房间仍可能单轮遍历无界，或账号路径边界失效");
}

int main()
{
	string error_desc = "";
	werror("\n========== 单进程运行时优化测试 ==========\n");
	mixed err = catch {
		test_thread_farm_io();
		test_parallel_command_source();
		test_heartbeat_budget_and_metrics();
		test_save_and_cache_metrics();
		test_afk_scan_budget_and_auth_boundary();
	};
	if(err){
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
		check("测试运行时无异常",0,error_desc);
	}
	werror("\n单进程优化测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
