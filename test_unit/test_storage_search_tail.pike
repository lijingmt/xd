#!/usr/bin/env pike
/** 建议1回归：仓库/批量赠送界面的关键词搜索与尾页直达。 */

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
	player->name_cn = "搜索尾页测试";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

int main()
{
	object original_player = this_player();
	object gift_command =
		(object)(ROOT+"/gamelib/cmds/batch_gift.pike");
	object gift_filter_command =
		(object)(ROOT+"/gamelib/cmds/batch_gift_filter.pike");
	object storage_command =
		(object)(ROOT+"/gamelib/cmds/personal_storage.pike");
	object|zero sender = 0;
	object|zero receiver = 0;
	array(object) medicines = ({});
	array(object) books = ({});
	mixed err = catch {
		sender = create_player("__testunit_gift_search_a__");
		receiver = create_player("__testunit_gift_search_b__");
		sender->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		receiver->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		set_this_player(sender);
		// 15瓶金疮药 + 9本技能书 = 24件可赠送物品，3页（每页10件）。
		for(int i=0;i<15;i++){
			object one = clone(ROOT+"/gamelib/clone/item/food/jinchuangyao");
			one->move(sender);
			medicines += ({one});
		}
		for(int i=0;i<9;i++){
			object one = clone(ROOT+"/gamelib/clone/item/book/lingzhen");
			one->move(sender);
			books += ({one});
		}
		int giftable = 1;
		foreach(all_inventory(sender),object item)
			if(!PLAYER_TRANSFERD->can_batch_gift_item(
				sender,receiver,item))
				giftable = 0;
		check("测试物品全部可批量赠送",giftable,
			"金疮药或灵真秘籍不可赠送，测试前提不成立");

		string page_one = gift_command->render_page(sender,receiver,0);
		check("批量赠送多页时展示页码与尾页直达",
			search(page_one,"第1/3页")!=-1 &&
			search(page_one,"[尾页:batch_gift page "+
				(string)receiver->query_name()+" 2]")!=-1 &&
			search(page_one,"关键词：[submit 搜索:batch_gift_filter "+
				(string)receiver->query_name()+" search ...]")!=-1,
			"首页渲染="+page_one);
		string page_three = gift_command->render_page(sender,receiver,2);
		check("批量赠送尾页直达渲染最后一页",
			search(page_three,"第3/3页")!=-1 &&
			search(page_three,"[尾页:")<0,
			"第3页渲染="+page_three);

		set_this_player(sender);
		gift_filter_command->main((string)receiver->query_name()+
			" search lingzhen");
		check("批量赠送关键词搜索只保留匹配物品并回显关键词",
			stringp(sender["/tmp/batch_gift/keyword"]) &&
			(string)sender["/tmp/batch_gift/keyword"]=="lingzhen",
			"关键词状态="+sprintf("%O",sender["/tmp/batch_gift/keyword"]));
		string filtered = gift_command->render_page(sender,receiver,0);
		check("批量赠送搜索结果过滤非匹配物品",
			search(filtered,"当前关键词：lingzhen")!=-1 &&
			search(filtered,"金疮药")<0 &&
			search(filtered,"第1/1页")!=-1,
			"过滤后渲染="+filtered);
		gift_filter_command->main((string)receiver->query_name()+
			" clear");
		check("批量赠送清除筛选恢复全量列表",
			stringp(sender["/tmp/batch_gift/keyword"]) &&
			(string)sender["/tmp/batch_gift/keyword"]=="" &&
			search(gift_command->render_page(sender,receiver,0),
				"第1/3页")!=-1,
			"清除后关键词未复位");

		// 批量仓库助手：关键词行过滤（查询函数为公开接口）。
		array rows = storage_command->query_backpack_rows(
			sender,"all","lingzhen");
		check("批量仓库关键词搜索只命中匹配行",
			sizeof(rows)==9,
			"命中行数="+(string)sizeof(rows));
		array all_rows = storage_command->query_backpack_rows(
			sender,"all","");
		check("批量仓库无关键词时返回全部可存物品",
			sizeof(all_rows)==24,
			"全部行数="+(string)sizeof(all_rows));
		string storage_source = Stdio.read_file(
			ROOT+"/gamelib/cmds/personal_storage.pike");
		check("批量仓库助手提供尾页直达链接",
			storage_source &&
			search(storage_source,
				"[尾页:personal_storage \"+mode+\" \"+max_page+\"]")!=-1,
			"personal_storage 缺少尾页链接");

		// 端到端：命令层入口把搜索词安全回显且不破坏按钮语法。
		sender["/tmp/batch_gift/keyword"] = "测试[危险:cmd]";
		string escaped = gift_command->render_page(sender,receiver,0);
		check("批量赠送回显关键词转义方括号与冒号",
			search(escaped,"当前关键词：测试［危险：cmd］")!=-1 &&
			search(escaped,"[危险:cmd]")<0,
			"转义渲染="+escaped);
		sender["/tmp/batch_gift/keyword"] = "";
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("仓库赠送搜索尾页流程无异常",0,describe_error(err));
	else
		check("仓库赠送搜索尾页流程无异常",1,"");
	foreach(medicines+books,object item)
		if(item)
			destruct(item);
	destroy_player(sender);
	destroy_player(receiver);
	werror("[仓库赠送搜索尾页] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
