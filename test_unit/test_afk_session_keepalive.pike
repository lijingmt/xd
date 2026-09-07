#!/usr/bin/env pike
/** 挂机会话保活回归：额度耗尽等运行时自停后，服务端tick只刷新
 * HTTP虚拟连接不再派发战斗，后台玩家不会被空闲清理踢下线；
 * 保活期过后恢复正常空闲规则；玩家主动关闭立即完整摘除。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	test_results["total"]++;
	if(valid){
		test_results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		test_results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

string player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

int main()
{
	string account_id = "xd01testunithold";
	string password = "testunit99";
	werror("\n========== 挂机会话保活测试 ==========\n");
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	rm(player_file(account_id));
	object httpd = (object)(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	object|zero me = 0;
	mixed err = catch{
		object seed = clone(GAMELIB_USER);
		seed->set_name(account_id);
		seed->set_password(password);
		seed->set_project("gamelib");
		seed->set_userip("testunit-hold");
		seed->name_cn = "会话保活测试";
		seed->set_raceId("human");
		seed->set_profeId("jianxian");
		seed->setup_player("human","jianxian");
		seed->save_with_result();
		destruct(seed);

		httpd->execute_core_command(account_id,password,"init");
		me = httpd->get_player_from_connection(account_id,0);
		check("测试角色建立HTTP虚拟连接",objectp(me),"登录失败");
		if(!me)
			return 1;
		me->move(ROOT+"/gamelib/d/congxianzhen/shanshulin");
		me["/plus/autofight_smart_route"] = 0;
		me["/plus/autofight_roam"] = 0;

		/* 1) 额度耗尽自停 → 会话保活 */
		me["/plus/autofight_initialized"] = 1;
		me["/plus/autofight_daily_limit"] = 4*60*60;
		me["/plus/autofight_time_left"] = 0;
		AUTOFIGHTD->start_autofight(me);
		check("开启挂机后服务端调度生效",
			me->query_autofight()=="enable" &&
			AUTOFIGHTD->query_server_autofight_tick_active(me)==1,
			"tick未激活");
		string out = httpd->execute_core_command(
			account_id,password,"flushview");
		check("额度耗尽触发自停并保留保活",
			me->query_autofight()=="disable" &&
			AUTOFIGHTD->query_session_hold_active(me)==1 &&
			AUTOFIGHTD->query_server_autofight_tick_active(me)==1 &&
			search(out,"自动挂机已停止")!=-1,
			sprintf("af=%s hold=%d tick=%d",
				me->query_autofight(),
				AUTOFIGHTD->query_session_hold_active(me),
				AUTOFIGHTD->query_server_autofight_tick_active(me)));
		/* 保活分支会刷新虚拟连接：sleep()不触发call_out，直接同步
		 * 驱动一次扫描，并把last_used先回拨以证明是扫描刷的。 */
		httpd->set_virtual_connection(account_id,
			({0,time()-120,me}));
		int before = time();
		AUTOFIGHTD->run_server_autofight_scan_for_test();
		mapping conn = httpd->query_connection_status();
		int last_used = 0;
		if(conn && arrayp(conn["connections"]))
			foreach(conn["connections"],mixed row){
				if(mappingp(row) &&
				   (string)row["userid"]==account_id)
					last_used = (int)row["last_used"];
			}
		check("自停后虚拟连接仍被tick刷新",
			last_used>=before && last_used<=time(),
			sprintf("last_used=%d before=%d now=%d",
				last_used,before,time()));

		/* 2) 保活过期 → 恢复正常摘除与空闲清理 */
		me["/tmp/autofight_session_hold_until"] = time()-1;
		AUTOFIGHTD->run_server_autofight_scan_for_test();
		check("保活过期后调度被正常摘除",
			AUTOFIGHTD->query_server_autofight_tick_active(me)==0,
			"epoch残留");
		httpd->set_virtual_connection(account_id,
			({0,time()-4000,me}));
		httpd->cleanup_idle_connections();
		check("保活过期且空闲超时后允许踢出",
			httpd->get_player_from_connection(account_id,0)==0,
			"玩家未被清理");
		me = 0;

		/* 3) 玩家主动关闭 → 立即完整摘除（无保活） */
		httpd->execute_core_command(account_id,password,"init");
		me = httpd->get_player_from_connection(account_id,0);
		if(objectp(me)){
			me["/plus/autofight_time_left"] = 4*60*60;
			AUTOFIGHTD->start_autofight(me);
			AUTOFIGHTD->stop_autofight(me);
			check("玩家主动关闭立即完整摘除",
				me->query_autofight()=="disable" &&
				AUTOFIGHTD->query_server_autofight_tick_active(me)==0 &&
				!AUTOFIGHTD->query_session_hold_active(me),
				"主动关闭仍保留调度");
		}
		else
			check("玩家主动关闭立即完整摘除",0,"重新登录失败");

		/* 4) tick断链防护：异常不得打断call_out续链 */
		string src = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/autofightd.pike") || "";
		check("tick扫描体包catch且重挂在catch之外",
			search(src,"catch { server_autofight_scan(); }")!=-1 &&
			search(src,"tick_err ? 1 : server_autofight_scan_delay")!=-1,
			"断链防护缺失");
		string fsrc = Stdio.read_file(ROOT+
			"/lowlib/wapmud2/cmds/flushview.pike") || "";
		check("运行时自停走保活停机",
			search(fsrc,"hold_session_after_stop")!=-1 &&
			search(fsrc,"stop_autofight(me,1)")!=-1,
			"stop_with_reason未接保活");
		check("保活与扫描文件可由真实Pike编译",
			!catch{ compile_file(ROOT+
				"/gamelib/single/daemons/autofightd.pike"); } &&
			!catch{ compile_file(ROOT+
				"/lowlib/wapmud2/cmds/flushview.pike"); },
			"编译失败");
	};
	if(err)
		check("流程无异常",0,describe_error(err));
	else
		check("流程无异常",1,"");
	if(me){
		me->set_autofight("disable");
		me->save_with_result();
		destruct(me);
	}
	httpd->remove_virtual_connection(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	rm(player_file(account_id));
	werror("========== 会话保活测试结束 ==========\n");
	return test_results["failed"]>0 ? 1 : 0;
}
