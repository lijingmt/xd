#!/usr/bin/env pike
/** 在线快照route_mismatch定向自愈回归（2026-09-10两次全集群重启根因）。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	werror("\n[快照分歧自愈 %d] %s\n",results["total"],name);
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

int main()
{
	object httpd=(object)(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string gateway=Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/pike_gateway.pike");
	string worker_rpc=Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike");

	mapping row=(["userid":"xd01mismt","worker_id":"w01","epoch":7]);
	mapping route_active=(["ok":1,"state":"active","worker_id":"w01",
		"epoch":7]);
	check("路由与行一致时通过校验",
		httpd->test_pike_gateway_online_row_reject_reason(row,"w01",
			time(),route_active,({}))=="",
		"一致数据被误拒");
	check("租约过期(路由ok=0)判为route_mismatch",
		httpd->test_pike_gateway_online_row_reject_reason(row,"w01",
			time(),(["ok":0,"code":"lease_expired"]),({}))==
			"online_route_mismatch",
		"过期租约未被识别为分歧");
	check("路由在他worker判为route_mismatch",
		httpd->test_pike_gateway_online_row_reject_reason(row,"w01",
			time(),(["ok":1,"state":"active","worker_id":"w02",
				"epoch":7]),({}))=="online_route_mismatch",
		"跨worker所有权被放过");
	check("同worker但epoch不一致判为route_mismatch",
		httpd->test_pike_gateway_online_row_reject_reason(row,"w01",
			time(),(["ok":1,"state":"active","worker_id":"w01",
				"epoch":9]),({}))=="online_route_mismatch",
		"epoch漂移被放过");
	check("已被接受的同名行判为duplicate_online_owner",
		httpd->test_pike_gateway_online_row_reject_reason(row,"w01",
			time(),route_active,({"xd01mismt"}))==
			"duplicate_online_owner",
		"重复所有权未被识别");
	check("行epoch非法判为invalid_online_owner",
		httpd->test_pike_gateway_online_row_reject_reason(
			(["userid":"xd01mismt","worker_id":"w01","epoch":0]),"w01",
			time(),route_active,({}))=="invalid_online_owner",
		"非法epoch行被放过");
	check("prepared交接冻结源仍走豁免不被误杀",
		httpd->test_pike_gateway_online_row_reject_reason(row,"w01",
			time(),(["ok":1,"state":"frozen","worker_id":"w01",
				"epoch":7,"handoff_request_id":"r"*32]),({}))=="",
		"交接冻结中的合法源被当成分歧");

	int now=time();
	check("同一肇事者持续120秒才触发定向清理",
		!httpd->test_pike_gateway_mismatch_heal_due(now-119,now) &&
		httpd->test_pike_gateway_mismatch_heal_due(now-120,now) &&
		!httpd->test_pike_gateway_mismatch_heal_due(0,now),
		"清理阈值边界错误：过早就踢玩家或过晚错过600s升级窗口");

	check("快照校验失败日志必须带userid引用与路由详情",
		source_has(gateway,
			"validation attempt=%d code=%s") &&
		source_has(gateway,"user_ref=") &&
		source_has(gateway,"route_worker=") &&
		source_has(gateway,"route_epoch="),
		"线上仍无法定位肇事玩家");
	check("定向自愈已接入恢复路径且成功发布清零追踪",
		source_has(gateway,"pike_gateway_heal_persistent_online_mismatches") &&
		source_has(gateway,
			"pike_gateway_heal_persistent_online_mismatches();") &&
		source_has(gateway,
			"pike_gateway_online_mismatch_since = ([]);") &&
		source_has(gateway,"MISMATCH_HEAL") &&
		!source_has(gateway,"pike_gateway_fast_zombie_sweep"),
		"自愈未接线、成功不清零或危险的无豁免清扫仍存在");
	check("live_leases遇无效玩家跳过上报而不是整页409",
		source_has(worker_rpc,"skipped_invalid") &&
		source_has(worker_rpc,"invalid_live") &&
		!source_has(worker_rpc,"code\":\"invalid_live_player") &&
		source_has(worker_rpc,"local_user_request_running(userid)"),
		"一个epoch=0玩家仍会让整个Worker的租约续期失败");
	check("自愈与发布校验共享同一裁决函数",
		source_has(gateway,"pike_gateway_online_row_reject_reason(row,"+
			"worker_id") &&
		source_has(gateway,
			"pike_gateway_online_row_reject_reason(row,row_worker"),
		"清理判定与校验判定可能分叉");

	werror("快照分歧自愈测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
