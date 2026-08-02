#!/usr/bin/env pike
/** 在线活动时间、HTTP只读轮询和空闲踢线策略回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void test_start(string name)
{
	test_results["total"]++;
	werror("\n[空闲踢线 %d] %s\n",test_results["total"],name);
}

void test_pass()
{
	test_results["passed"]++;
	werror("  ✓ 通过\n");
}

void test_fail(string reason)
{
	test_results["failed"]++;
	werror("  ✗ 失败: %s\n",reason);
}

object create_player(string name)
{
	object player = clone(GAMELIB_USER);
	player->set_name(name);
	player->name_cn = "空闲测试人物";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level = 20;
	player->set_att_by_level();
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	if(player->query_in_combat())
		player->_clean_fight();
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

void test_runtime_compile_and_startup()
{
	test_start("用户活动、踢线守护与HTTP虚拟连接可运行时编译并自动加载");
	array(string) paths = ({
		"/lowlib/system/inherit/user.pike",
		"/gamelib/single/daemons/idle_kickd.pike",
		"/gamelib/single/daemons/http_api_daemon.pike",
	});
	string master_source = Stdio.read_file(ROOT+"/lowlib/system/master.pike");
	int failed = 0;
	string error_desc = "";
	foreach(paths,string path){
		mixed err = catch {
			program compiled = (program)(ROOT+path);
			if(!compiled) failed++;
		};
		if(err){ failed++; error_desc += path+":"+describe_error(err); }
	}
	if(failed==0 && master_source &&
	   search(master_source,"call_out(load_daemons, 2)")!=-1)
		test_pass();
	else
		test_fail("编译或启动接线失败: "+error_desc);
}

void test_real_activity_clock()
{
	test_start("真实输入、核心/非核心HTTP操作刷新活动时间，挂机状态有独立显示");
	object player = create_player("__testunit_idle_clock__");
	object httpd = (object)(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string userid = player->query_name();
	httpd->set_virtual_connection(userid,({0,time()-30,player}));
	player->mark_user_activity();
	int direct_idle = player->query_idle();
	httpd->update_connection_time(userid);
	mapping state = httpd->query_connection_status();
	int connection_idle = -1;
	foreach((array)state["connections"],mapping one)
		if(one["userid"]==userid)
			connection_idle = (int)one["idle_seconds"];
	httpd->set_virtual_connection(userid,({0,time()-30,player}));
	httpd->execute_internal_command_sync(userid,"","__idle_activity_probe__");
	state = httpd->query_connection_status();
	int parallel_command_idle = -1;
	foreach((array)state["connections"],mapping one)
		if(one["userid"]==userid)
			parallel_command_idle = (int)one["idle_seconds"];
	player->set_autofight("enable");
	string label = player->query_idle_label();
	player->set_autofight("disable");
	httpd->remove_virtual_connection(userid);
	if(direct_idle>=0 && direct_idle<=1 && connection_idle>=0 &&
	   connection_idle<=1 && parallel_command_idle>=0 &&
	   parallel_command_idle<=1 && label=="<挂机中>")
		test_pass();
	else
		test_fail(sprintf("人物空闲=%d 连接空闲=%d 非核心命令=%d 标签=%s",
			direct_idle,connection_idle,parallel_command_idle,label));
	destroy_player(player);
}

void test_normal_vip_and_expiry_boundaries()
{
	test_start("普通60分钟、有效VIP120分钟且过期会员立即回归普通规则");
	object player = create_player("__testunit_idle_policy__");
	int normal_timeout = IDLE_KICKD->query_timeout_for(player);
	int normal_before = IDLE_KICKD->should_kick_user(player,3599);
	int normal_at = IDLE_KICKD->should_kick_user(player,3600);
	player->set_vip_flag(4);
	player->set_vip_end_time(time()+3600);
	int vip_timeout = IDLE_KICKD->query_timeout_for(player);
	int vip_before = IDLE_KICKD->should_kick_user(player,7199);
	int vip_at = IDLE_KICKD->should_kick_user(player,7200);
	player->set_vip_end_time(time()-1);
	int expired_timeout = IDLE_KICKD->query_timeout_for(player);
	if(normal_timeout==3600 && !normal_before && normal_at &&
	   vip_timeout==7200 && !vip_before && vip_at &&
	   expired_timeout==3600)
		test_pass();
	else
		test_fail(sprintf("normal=%d/%d/%d vip=%d/%d/%d expired=%d",
			normal_timeout,normal_before,normal_at,
			vip_timeout,vip_before,vip_at,expired_timeout));
	destroy_player(player);
}

void test_read_only_polling_does_not_keep_alive()
{
	test_start("人物、战斗、房间与聊天轮询不能给空闲连接续命");
	string daemon = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string virtual_conn = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/virtual_conn.pike");
	int status_start = search(daemon,"void handle_api_status(");
	int status_end = search(daemon,"object|zero query_battle_enemy",status_start);
	string status_block = status_start>=0 && status_end>status_start ?
		daemon[status_start..status_end-1] : "";
	int valid = daemon && virtual_conn && status_block!="" &&
		search(status_block,"update_connection_time") == -1 &&
		search(status_block,"get_player_from_connection(userid, 0)") != -1 &&
		search(daemon,"只读API：不更新闲置时间") != -1 &&
		search(virtual_conn,"IDLE_KICKD->query_timeout_for(player)") != -1 &&
		search(virtual_conn,"idle_time >= timeout") != -1 &&
		search(virtual_conn,"now-(int)current[1]>=timeout") != -1;
	if(valid)
		test_pass();
	else
		test_fail("只读轮询仍可能续命，或超时边界未统一");
}

void test_online_list_uses_activity_label()
{
	test_start("好友、帮派和管理员在线列表统一使用真实活动标签");
	array(string) paths = ({
		"/lowlib/wapmud2/inherit/feature/qqlist.pike",
		"/lowlib/wapmud2/single/bangd.pike",
		"/gamelib/cmds/game_deal.pike",
	});
	int valid = 1;
	foreach(paths,string path){
		string source = Stdio.read_file(ROOT+path);
		if(!source || search(source,"query_idle_label()") == -1 ||
		   search(source,"<发呆\"+") != -1)
			valid = 0;
	}
	if(valid)
		test_pass();
	else
		test_fail("至少一个在线列表仍把登录时长当发呆时长");
}

int main(int argc,array(string) argv)
{
	werror("\n========== 空闲踢线系统测试 ==========\n");
	test_runtime_compile_and_startup();
	test_real_activity_clock();
	test_normal_vip_and_expiry_boundaries();
	test_read_only_polling_does_not_keep_alive();
	test_online_list_uses_activity_label();
	werror("\n空闲踢线测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
