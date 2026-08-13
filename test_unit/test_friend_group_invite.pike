#!/usr/bin/env pike
/** 好友分组一键组队保持确认制、五人上限和现有隔离规则。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

object create_player(string userid,string name_cn)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn = name_cn;
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->set_term("noterm");
	return player;
}

int main()
{
	object original = this_player();
	object leader = create_player("xd98testunitfriendleader","好友队长");
	array(object) friends = ({});
	object command = (object)(ROOT+
		"/gamelib/cmds/qqlist_group_invite.pike");
	int pending = 0;
	for(int i=0;i<5;i++){
		object one = create_player("xd98testunitfriend0"+i,
			"分组好友"+i);
		friends += ({one});
	}
	leader->qqlist_group_create("常用队友");
	foreach(friends,object one){
		leader->qqlist_insert(one->query_name(),"");
		leader->qqlist_group_insert(one->query_name(),"1");
	}
	set_this_player(leader);
	command->main("1");
	foreach(friends,object one)
		if(TERMD->query_term_invite(one->query_name())["pending"])
			pending++;
	string team_id = leader->query_term();
	check("已有好友分组直接提供一键组队入口",
		search(leader->view_qqlist_groups(),
			"[一键组队:qqlist_group_invite 1]")!=-1 &&
		search(leader->view_qqlist_group("1"),
			"[邀请本组在线好友组队:qqlist_group_invite 1]")!=-1,
		"分组列表或分组详情缺少快捷入口");
	check("一键组队只发确认邀请且最多填满五人队",
		pending==4 && TERMD->query_termId(team_id) &&
		TERMD->get_term_power(team_id,leader->query_name())=="leader" &&
		sizeof(TERMD->query_term_m(team_id))==1,
		"批量邀请绕过确认、突破容量或没有建立队伍");
	if(TERMD->query_termId(team_id))
		TERMD->destory_term(team_id,leader->query_name());
	foreach(friends,object one){
		TERMD->clear_term_invite(one->query_name(),leader->query_name());
		if(one) destruct(one);
	}
	if(leader) destruct(leader);
	if(original)
		set_this_player(original);
	else
		set_this_player(this_object());
	werror("好友分组组队测试：%d通过/%d失败\n",
		results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
