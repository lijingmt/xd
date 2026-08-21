#!/usr/bin/env pike
/** 分类背包、按件分页、跳页搜索和装备展示叠加回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[分类背包] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[分类背包] ✗ %s: %s\n",name,detail);
	}
}

object create_test_player()
{
	object player=clone(GAMELIB_USER);
	player->set_name("xd01testunitinventorybrowser");
	player->name_cn="分类背包测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=70;
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

void populate_inventory(object player)
{
	for(int i=0;i<65;i++){
		object food=clone(ROOT+"/gamelib/clone/item/food/ganliang");
		// 玩家显式标记不同的物品不能被堆叠洗掉标记；同时保留
		// 65个独立对象，用来验证分类背包的真实三页导航。
		food->item_playerDesc="pagination-"+i;
		food->move(player);
	}
	object first=clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	object second=clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	object different=clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	first->move(player);
	second->move(player);
	different->set_convert_count(1);
	different->set_original_name_cn("[伪造:drop all]");
	different->move(player);
	object jade=clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
	object box=clone(ROOT+"/gamelib/clone/item/baoxiang/chr_bx_1");
	object material=clone(ROOT+
		"/gamelib/clone/item/baoshi/slqingtongshi");
	object book=clone(ROOT+
		"/gamelib/clone/item/peifang/duanzao/p_moxie");
	object set_item=clone(ROOT+
		"/gamelib/clone/item/weapon/69xinyuetianfengjian/69xinyuetianfengjian");
	jade->move(player);
	box->move(player);
	material->move(player);
	book->set_item_task(1);
	book->move(player);
	set_item->move(player);
}

void test_categories_and_paging(object player)
{
	mapping medicine=player->query_inventory_browser_snapshot("medicine","");
	string first_page=player->view_inventory_browser("medicine",1,"");
	string last_page=player->view_inventory_browser("medicine",99,"");
	check("服务端统一分类覆盖套装、药品、装备、玉石、宝箱、材料和任务",
		(int)medicine["counts"]["medicine"]==65 &&
		(int)medicine["counts"]["equipment"]==3 &&
		(int)medicine["counts"]["set"]==1 &&
		(int)medicine["counts"]["jade"]==1 &&
		(int)medicine["counts"]["box"]==1 &&
		(int)medicine["counts"]["material"]==1 &&
		(int)medicine["counts"]["quest"]==1,
		sprintf("counts=%O",medicine["counts"]));
	check("30件一页并提供首页、尾页、上一页和下一页",
		search(first_page,"第1/3页")!=-1 &&
		search(first_page,"[下一页:inventory_filter page 2]")!=-1 &&
		search(first_page,"[尾页:inventory_filter page 3]")!=-1 &&
		search(last_page,"第3/3页")!=-1 &&
		search(last_page,"[首页:inventory_filter page 1]")!=-1 &&
		search(last_page,"[上一页:inventory_filter page 2]")!=-1 &&
		search(last_page,"[下一页:")==-1,
		first_page+"\n---\n"+last_page);
	check("搜索框和页码跳转框同时兼容括号命令",
		search(first_page,"[inventory_filter search ...]")!=-1 &&
		search(first_page,"[inventory_filter jump ...]")!=-1 &&
		search(first_page,"[inventory_filter category ...]")!=-1 &&
		search(first_page,":inventory_filter category equipment]")==-1 &&
		search(player->view_inventory_browser("set",1,""),
			"当前筛选：套装(1)")!=-1,
		first_page);
}

void test_equipment_display_groups(object player)
{
	mapping equipment=player->query_inventory_browser_snapshot("equipment","");
	array entries=equipment["entries"];
	string grouped_id="";
	int grouped=0;
	for(int i=0;i<sizeof(entries);i++)
		if((int)entries[i]["group_count"]==2){
			grouped=1;
			grouped_id=(string)entries[i]["group_id"];
		}
	string rendered=player->view_inventory_browser("equipment",1,"");
	string detail=grouped_id!="" ?
		player->view_inventory_equipment_group(grouped_id,1) : "";
	check("完整状态相同的装备只合并展示而不合并对象",
		(int)equipment["matched_physical"]==3 && sizeof(entries)==2 &&
		grouped && sizeof(all_inventory(player))==73 &&
		search(rendered,"×2")!=-1 &&
		search(rendered,"[伪造:drop all]")==-1 &&
		search(rendered,"（伪造：drop all）")!=-1,
		sprintf("physical=%d entries=%d grouped=%d inventory=%d",
			(int)equipment["matched_physical"],sizeof(entries),grouped,
			sizeof(all_inventory(player))));
	check("装备组详情仍能逐件选择原始对象",
		search(detail,"第1件")!=-1 && search(detail,"第2件")!=-1 &&
		search(detail,":inv 1taomujian 0]")!=-1 &&
		search(detail,":inv 1taomujian 1]")!=-1,
		detail);
}

void test_search_and_legacy_rendering(object player)
{
	string search_result=player->view_inventory_search("干粮");
	string injection=player->view_inventory_search("[恶意:drop all]");
	string rendered=HTTP_APID->response_to_html(
		"搜索：[inventory_filter search ...] 跳页：[inventory_filter jump ...]",
		player->query_name(),"inventory","zf12testunit~password");
	string dropdown=HTTP_APID->response_to_html(
		"筛选：[inventory_filter category ...]",
		player->query_name(),"inventory","zf12testunit~password");
	string view_source=Stdio.read_file(ROOT+
		"/lowlib/wapmud2/single/viewd.pike");
	string vue_index=Stdio.read_file(ROOT+"/vue_source/index.html");
	string vue_app=Stdio.read_file(ROOT+"/vue_source/js/app.js");
	check("旧搜索命令升级为可分页搜索且不回显恶意命令",
		search(search_result,"找到65件匹配物品")!=-1 &&
		search(search_result,"第1/3页")!=-1 &&
		search(injection,"drop all")==-1,
		search_result+"\n---\n"+injection);
	check("旧JSP与Vue均可渲染搜索、跳页和单一下拉筛选",
		search(rendered,"<input type='text'")!=-1 &&
		search(rendered,"submitCmdInput")!=-1 &&
		search(dropdown,"<select")!=-1 &&
		search(dropdown,"inventory_filter category")!=-1 &&
		search(dropdown,"value='set'>套装")!=-1 &&
		vue_index && search(vue_index,"mud-category-select")!=-1 &&
		search(vue_index,"submitCmdSelect(segment.cmd, $event)")!=-1 &&
		vue_app && search(vue_app,"submitCmdSelect(cmdName, event)")!=-1 &&
		view_source && search(view_source,
			"$(player->view_inventory_zhuangbei())")!=-1 &&
		search(view_source,"筛选物品：[inventory_filter category ...]")!=-1 &&
		search(view_source,"$(player->view_inventory_browser())")==-1 &&
		search(player->view_inventory_browser("all",1,""),
			"[返回装备背包:inventory]")!=-1 &&
		search(player->view_inventory_browser("all",1,""),
			"[套装管理:set_equipment_cleanup]")!=-1,
		rendered+"\n---\n"+dropdown);
	mixed err=catch {
		compile_file(ROOT+"/lowlib/wapmud2/cmds/inventory_filter.pike");
		compile_file(ROOT+"/lowlib/wapmud2/cmds/inventory_legacy.pike");
		compile_file(ROOT+"/gamelib/cmds/set_equipment_cleanup.pike");
	};
	check("分类背包命令可由真实Pike运行时编译",!err,
		err ? describe_error(err) : "");
}

int main()
{
	object|zero original_player=this_player();
	object player=create_test_player();
	set_this_player(player);
	mixed err=catch {
		populate_inventory(player);
		test_categories_and_paging(player);
		test_equipment_display_groups(player);
		test_search_and_legacy_rendering(player);
	};
	if(err)
		check("测试运行时无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	destroy_test_player(player);
	werror("分类背包测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
