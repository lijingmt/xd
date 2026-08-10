#!/usr/bin/env pike
/** 背包名称搜索、圣诞宝箱叠加与有界批量开启回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[背包优化] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[背包优化] ✗ %s: %s\n",name,detail);
	}
}

object create_test_player()
{
	object player=clone(GAMELIB_USER);
	player->set_name("xd01testunitinventorysearch");
	player->name_cn="背包优化测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=20;
	player->set_att_by_level();
	return player;
}

void destroy_test_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		if(item)
			destruct(item);
	destruct(player);
}

void test_search(object player)
{
	object weapon=clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	weapon->move(player);
	string found=player->view_inventory_search("桃木");
	string missing=player->view_inventory_search("肯定不存在的物品");
	string injection=player->view_inventory_search("[恶意:drop all]");
	string prompt=player->view_inventory_search("");
	string rendered=HTTP_APID->response_to_html(
		"搜索物品：[inventory_search ...]",player->query_name(),"inventory",
		"zf12testunit~password");
	check("装备和道具页都有统一搜索输入框",
		search(Stdio.read_file(ROOT+"/lowlib/wapmud2/single/viewd.pike"),
			"搜索物品：[inventory_search ...]")!=-1 &&
		search(prompt,"[inventory_search ...]")!=-1 &&
		search(rendered,"<input type='text'")!=-1 &&
		search(rendered,"submitCmdInput")!=-1 &&
		search(rendered,"c_")!=-1 &&
		search(rendered,"[inventory_search ...]")==-1,
		"搜索入口未接入旧JSP视图");
	check("中文名称局部匹配返回原有物品详情动作",
		search(found,"桃木剑")!=-1 && search(found,":inv 1taomujian 0]")!=-1,
		found);
	check("无结果和恶意标记输入均不生成客户端命令",
		search(missing,"没有找到匹配的物品")!=-1 &&
		search(injection,"drop all")==-1,
		injection);
}

void test_christmas_box_stack_and_batch(object player)
{
	object ordinary=clone(ROOT+"/gamelib/clone/item/food/ganliang");
	ordinary->move(player);
	int inventory_before=sizeof(all_inventory(player));
	object command=(object)(ROOT+"/gamelib/cmds/bx_open.pike");
	command->main("ganliang 0 20");
	check("伪造普通物品名不能进入圣诞宝箱奖励逻辑",
		objectp(ordinary) && environment(ordinary)==player &&
		sizeof(all_inventory(player))==inventory_before,
		sprintf("ordinary=%O before=%d after=%d",ordinary,
			inventory_before,sizeof(all_inventory(player))));
	object first=clone(ROOT+"/gamelib/clone/item/baoxiang/chr_bx_1");
	object second=clone(ROOT+"/gamelib/clone/item/baoxiang/chr_bx_1");
	first->move(player);
	second->move(player);
	int normalized=player->normalize_christmas_box_stacks();
	array(object) boxes=filter(all_inventory(player),lambda(object item){
		return item && item->query_name()=="chr_bx_1";
	});
	object box=sizeof(boxes) ? boxes[0] : 0;
	check("老档案独立圣诞宝箱守恒整理为同一堆叠",
		normalized==1 && sizeof(boxes)==1 && box &&
		box->is("combine_item") && box->amount==2,
		sprintf("groups=%d amount=%d",sizeof(boxes),box ? box->amount : 0));
	object picked=clone(ROOT+"/gamelib/clone/item/baoxiang/chr_bx_1");
	picked->move_player(player->query_name());
	check("新拾取同级圣诞宝箱自动并入现有堆叠",
		box->amount==3 && environment(picked)!=player,
		"amount="+(string)box->amount);
	check("叠加宝箱同时提供单开和有界批量开启",
		box && search(box->query_inventory_links(0),"bx_open chr_bx_1 0 1")!=-1 &&
		search(box->query_inventory_links(0),"bx_open chr_bx_1 0 20")!=-1,
		box ? box->query_inventory_links(0) : "missing box");
	command->main("chr_bx_1 0 20");
	boxes=filter(all_inventory(player),lambda(object item){
		return item && item->query_name()=="chr_bx_1";
	});
	check("批量开启按实际数量逐个扣除且不会误留空栈",
		sizeof(boxes)==0,"remaining groups="+(string)sizeof(boxes));
}

int main()
{
	object|zero original_player=this_player();
	object player=create_test_player();
	set_this_player(player);
	mixed err=catch{
		test_search(player);
		test_christmas_box_stack_and_batch(player);
	};
	if(err)
		check("测试运行时无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	destroy_test_player(player);
	werror("背包优化测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
