#!/usr/bin/env pike
/** 管理后台在线人数统计与明细一致性回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

class NoRoomPlayerProbe
{
	string query_name()
	{
		return "__testunit_online_no_room__";
	}
	string query_name_cn()
	{
		return "无房间测试人物";
	}
	int query_level()
	{
		return 20;
	}
	string query_idle_label()
	{
		return "";
	}
}

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

object create_player(string name,string name_cn)
{
	object player = clone(GAMELIB_USER);
	player->set_name(name);
	player->name_cn = name_cn;
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level = 20;
	player->set_att_by_level();
	return player;
}

void destroy_player(object player)
{
	string name = "";
	if(!player)
		return;
	name = (string)player->query_name();
	if(name && sizeof(name))
		HTTP_APID->remove_virtual_connection(name);
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

void test_valid_snapshot_and_rows()
{
	object command_ob =
		(object)(ROOT+"/gamelib/cmds/game_deal.pike");
	object valid_player = create_player(
		"__testunit_online_valid__","在线统计测试人物");
	object no_room_player = NoRoomPlayerProbe();
	object stale_player = create_player(
		"__testunit_online_valid__","同账号旧人物对象");
	array(object) filtered;
	string row = "";
	valid_player->move(LOW_VOID_OB);
	stale_player->move(LOW_VOID_OB);
	HTTP_APID->set_virtual_connection(valid_player->query_name(),
		({0,time(),valid_player}));
	HTTP_APID->set_virtual_connection(no_room_player->query_name(),
		({0,time(),no_room_player}));
	filtered = command_ob->filter_valid_online_users(
		({valid_player,no_room_player,stale_player}));
	row = command_ob->build_online_user_row(valid_player,1);
	check("有效连接保留，无房间和同账号旧对象过滤",
		sizeof(filtered)==1 && filtered[0]==valid_player,
		"过滤后的在线玩家快照不正确");
	check("在线明细使用连续序号并可完整渲染",
		row && search(row,"1|20级|在线统计测试人物|")!=-1 &&
		search(row,"__testunit_online_valid__")!=-1,
		"有效玩家明细未生成或序号不连续");
	check("无房间对象不能生成在线明细",
		command_ob->build_online_user_row(no_room_player,2)=="",
		"无房间对象仍被视为可显示在线玩家");
	destroy_player(valid_player);
	destroy_player(stale_player);
	HTTP_APID->remove_virtual_connection(no_room_player->query_name());
	destruct(no_room_player);
}

void test_source_contract()
{
	string source = Stdio.read_file(
		ROOT+"/gamelib/cmds/game_deal.pike");
	int valid = source &&
		search(source,"filter_valid_online_users(users(1))")!=-1 &&
		search(source,"row = build_online_user_row(list[j],count+1)")!=-1 &&
		search(source,"string tbnow = list[j]->tongbao") == -1 &&
		search(source,"int count = sizeof(users())") == -1;
	check("计数与明细共用有效快照且移除易错无用字段",
		valid,"管理员列表仍可能先统计再静默跳过明细");
}

int main(int argc,array(string) argv)
{
	werror("\n========== 在线人数统计测试 ==========\n");
	test_valid_snapshot_and_rows();
	test_source_contract();
	werror("在线人数统计测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
