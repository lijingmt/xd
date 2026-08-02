#!/usr/bin/env pike
/** 同一注册账号双人物HTTP会话与挂机刷新隔离回归。 */

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

void cleanup_player(string userid)
{
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_saved_player(string userid,string password,string race_id,
	string profession_id)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->set_password(password);
	player->set_project("gamelib");
	player->set_userip("testunit-http-afk");
	player->name_cn = "双人物挂机测试";
	player->set_raceId(race_id);
	player->set_profeId(profession_id);
	player->setup_player(race_id,profession_id);
	player->save_with_result();
	return player;
}

int contains_login_error(string result)
{
	if(!result)
		return 1;
	return search(result,"登录失败")!=-1 ||
		search(result,"未登录")!=-1 ||
		search(result,"认证")!=-1;
}

int main()
{
	string account_id = "xd01testunithttpafk";
	string password = "testunit88";
	string child_id = "";
	object|zero seed = 0;
	object|zero child_seed = 0;
	object|zero first = 0;
	object|zero second = 0;
	object httpd = (object)(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	object original_player = this_player();
	werror("\n========== 双人物HTTP挂机隔离测试 ==========\n");
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	mixed err = catch{
		seed = create_saved_player(account_id,password,"human","jianxian");
		destruct(seed);
		seed = 0;
		mapping created = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi");
		if(created["ok"])
			child_id = (string)created["character"]["id"];
		check("建立同账号两个可登录人物档案",
			created["ok"] && child_id!="",
			(string)(created["message"] || "子人物创建失败"));

		child_seed = clone(GAMELIB_USER);
		child_seed->set_name(child_id);
		child_seed->set_project("gamelib");
		child_seed->restore();
		child_seed->name_cn = "双人物挂机方士";
		child_seed->set_raceId("third");
		child_seed->set_profeId("fangshi");
		child_seed->setup_player("third","fangshi");
		child_seed->save_with_result();
		destruct(child_seed);
		child_seed = 0;

		string first_login = httpd->execute_core_command(
			account_id,password,"init");
		string second_login = httpd->execute_core_command(
			child_id,password,"init");
		first = httpd->get_player_from_connection(account_id,0);
		second = httpd->get_player_from_connection(child_id,0);
		check("两个具体人物各自建立独立HTTP虚拟连接",
			first && second && first!=second &&
			first->query_name()==account_id &&
			second->query_name()==child_id &&
			!contains_login_error(first_login) &&
			!contains_login_error(second_login),
			"第二人物登录覆盖了第一个人物连接");
		if(first && second)
			httpd->set_virtual_connection(account_id,({0,time(),second}));
		check("连接池拒绝把另一职业对象写进当前人物槽位",
			httpd->get_player_from_connection(account_id,0)==first &&
			httpd->get_player_from_connection(child_id,0)==second,
			"错配人物对象进入了其他职业的连接槽");

		if(first && second){
			first->move(ROOT+"/gamelib/d/kunlunshan/wuge");
			second->move(ROOT+
				"/gamelib/d/congxianzhen/congxianzhenguangchang");
			first["/plus/autofight_smart_route"] = 0;
			second["/plus/autofight_smart_route"] = 0;
			first["/plus/autofight_roam"] = 0;
			second["/plus/autofight_roam"] = 0;
			first->set_autofight("enable");
			second->set_autofight("enable");
			first["/tmp/testunit_http_afk_marker"] = 101;
			second["/tmp/testunit_http_afk_marker"] = 202;
		}
		int refresh_ok = first && second;
		for(int i=0;i<8 && refresh_ok;i++){
			string first_refresh = httpd->execute_core_command(
				account_id,password,"flushview");
			string second_refresh = httpd->execute_core_command(
				child_id,password,"flushview");
			object current_first =
				httpd->get_player_from_connection(account_id,0);
			object current_second =
				httpd->get_player_from_connection(child_id,0);
			refresh_ok = current_first==first && current_second==second &&
				current_first!=current_second &&
				(int)current_first["/tmp/testunit_http_afk_marker"]==101 &&
				(int)current_second["/tmp/testunit_http_afk_marker"]==202 &&
				current_first->query_autofight()=="enable" &&
				current_second->query_autofight()=="enable" &&
				!contains_login_error(first_refresh) &&
				!contains_login_error(second_refresh);
		}
		check("双人物交替挂机刷新不会串连接、串状态或触发重登",
			refresh_ok,"flushview后人物对象或私有状态发生串扰");

		array(string) active = ACCOUNT_CHARACTERD->
			query_active_characters(account_id);
		check("连续挂机后账号在线登记仍保留两个人物",
			sizeof(active)==2 && search(active,account_id)!=-1 &&
			search(active,child_id)!=-1,
			"挂机刷新错误清退了同账号另一职业");

		check("HTTP连接池和挂机刷新相关文件可由真实Pike编译",
			!catch{ compile_file(ROOT+
				"/gamelib/single/daemons/http_api_daemon.pike"); } &&
			!catch{ compile_file(ROOT+
				"/lowlib/wapmud2/cmds/flushview.pike"); },
			"HTTP或挂机文件编译失败");
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("双人物HTTP挂机测试运行时无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(first){
		first->set_autofight("disable");
		first->save_with_result();
	}
	if(second){
		second->set_autofight("disable");
		second->save_with_result();
	}
	httpd->remove_virtual_connection(account_id);
	if(child_id!="")
		httpd->remove_virtual_connection(child_id);
	if(first)
		destruct(first);
	if(second)
		destruct(second);
	if(seed)
		destruct(seed);
	if(child_seed)
		destruct(child_seed);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	if(child_id!="")
		cleanup_player(child_id);
	cleanup_player(account_id);
	werror("双人物HTTP挂机隔离：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
