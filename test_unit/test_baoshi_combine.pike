#!/usr/bin/env pike
/** 宝石合成回归：三颗朴素换一颗闪亮、数量不足拒绝、命令可编译。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[宝石合成] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[宝石合成] ✗ %s: %s\n",name,detail);
	}
}

object create_test_player(string userid)
{
	object player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn="宝石合成测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=30;
	player->set_att_by_level();
	return player;
}

int gem_amount(object player,string name)
{
	int total=0;
	foreach(all_inventory(player),object item)
		if(item && (string)item->query_name()==name)
			total+=(int)item->amount;
	return total;
}

int main()
{
	object player=create_test_player("xd01testunitgemcombine");
	object|zero original=this_player();
	string error_desc="";
	int combined=0;
	int insufficient_refused=0;
	mixed err=catch{
		set_this_player(player);
		object five=clone(ROOT+"/gamelib/clone/item/baoshi/psroujinshi");
		five->amount=5;
		five->move(player);
		object two=clone(ROOT+"/gamelib/clone/item/baoshi/psbaijingshi");
		two->amount=2;
		two->move(player);
		object command=(object)(ROOT+"/gamelib/cmds/baoshi_combine.pike");
		command->main("psroujinshi");
		combined=gem_amount(player,"psroujinshi")==2 &&
			gem_amount(player,"slroujinshi")==1;
		int before=gem_amount(player,"psbaijingshi");
		command->main("psbaijingshi");
		insufficient_refused=gem_amount(player,"psbaijingshi")==before;
	};
	if(err)
		error_desc=describe_error(err);
	check("三颗朴素宝石合成一颗对应闪亮宝石且只消耗三颗",
		!err && combined,
		error_desc!="" ? error_desc :
			sprintf("psroujinshi=%d slroujinshi=%d",
				gem_amount(player,"psroujinshi"),
				gem_amount(player,"slroujinshi")));
	check("不足三颗的宝石拒绝合成且数量不变",
		!err && insufficient_refused,
		sprintf("psbaijingshi=%d",gem_amount(player,"psbaijingshi")));
	if(original)
		set_this_player(original);
	else
		set_this_player(this_object());
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
	werror("宝石合成：总计%d，通过%d，失败%d\n",results["total"],
		results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
