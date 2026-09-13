#!/usr/bin/env pike
/** 前缀装备清理回归：筛选边界+销毁守恒+保护项不误伤。 */

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

object create_player(string userid)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn = "前缀清理测试";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	return player;
}

int main()
{
	object original_player = this_player();
	object|zero me = 0;
	string error_desc = "";
	mixed err = catch {
		object cmd = (object)(
			ROOT+"/gamelib/cmds/prefix_gear_cleanup.pike");
		me = create_player("__testunit_prefix_clean__");
		me->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		set_this_player(me);
		object|zero keep1 = 0;
		object|zero keep2 = 0;
		object|zero keep3 = 0;
		array(object) junk = ({});
		// 3件空觉/破空/寂灭垃圾 + 3件保护件
		foreach(({8,9,10}),int rare){
			object ob = ITEMSD->get_convert_item(
				"armor/10lupimao/10lupimao",rare,10,10);
			if(ob){
				ob->move(me);
				junk += ({ob});
			}
		}
		keep1 = clone(ROOT+
			"/gamelib/clone/item/armor/10lupimao/10lupimao");
		keep1->set_item_rareLevel(9);
		keep1->move(me);
		keep2 = clone(ROOT+
			"/gamelib/clone/item/armor/10lupimao/10lupimao");
		keep2->set_item_rareLevel(10);
		keep2->move(me);
		me->wear(keep2); // 已装备→保护
		keep3 = clone(ROOT+
			"/gamelib/clone/item/armor/10lupimao/10lupimao");
		keep3->set_item_rareLevel(11);
		keep3->set_item_canDrop(0); // 不可丢弃→保护
		keep3->move(me);
		check("测试装备构造成功",sizeof(junk)==3 &&
			objectp(keep1) && objectp(keep2) && objectp(keep3),
			sprintf("junk=%d",sizeof(junk)));

		set_this_player(me);
		// 预览页含分类与确认按钮
		cmd->main("");
		// 执行清理（keep1未装备未绑定会一起被清，属预期规则）
		cmd->main("confirm");
		int junk_left = 0;
		foreach(junk,object ob)
			if(objectp(ob))
				junk_left++;
		check("空觉/破空/寂灭垃圾全部销毁",junk_left==0,
			"残留"+junk_left+"件");
		check("已装备与不可丢弃件被保护",
			objectp(keep2) && objectp(keep3),
			"保护件被误删");
		// 清理为纯销毁（生成的装备value=0，残值无意义），
		// 只验证物品计数守恒：3垃圾+keep1被清，keep2/keep3保留。
		int remaining = 0;
		foreach(all_inventory(me),object ob)
			remaining++;
		check("清理后背包物品数守恒",remaining==2,
			"remaining="+remaining);

		// 入口挂载
		string viewd_source = Stdio.read_file(
			ROOT+"/lowlib/wapmud2/single/viewd.pike");
		check("装备背包页提供前缀清理入口",
			viewd_source &&
			search(viewd_source,"[前缀装备清理:prefix_gear_cleanup]")!=-1,
			"入口缺失");
	};
	if(err)
		error_desc = describe_error(err);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(error_desc!="")
		check("前缀清理流程无异常",0,error_desc);
	else
		check("前缀清理流程无异常",1,"");
	if(me){
		foreach(all_inventory(me),object item)
			destruct(item);
		destruct(me);
	}
	werror("[前缀装备清理] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
