#!/usr/bin/env pike
/** 武阁快捷入口、免费容量与人物仓库存取回归。 */

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

object create_player(string userid,string race_id,string profession_id)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn = "武阁仓库测试人物";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race_id);
	player->set_profeId(profession_id);
	player->setup_player(race_id,profession_id);
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
	object go_command = (object)(ROOT+"/gamelib/cmds/go_warehouse.pike");
	object store_command = (object)(ROOT+"/gamelib/cmds/user_package.pike");
	object take_command = (object)(ROOT+"/gamelib/cmds/user_repackage.pike");
	array(array(string)) routes = ({
		({"human","jianxian","kunlunshan/wuge"}),
		({"monst","kuangyao","jinaodao/wuge"}),
		({"third","fangshi","kunlunshan/wuge"}),
	});
	array(object) players = ({});
	string error_desc = "";
	mixed err = catch {
		foreach(routes,array(string) route){
			object player = create_player(
				"__testunit_warehouse_"+route[0]+"__",
				route[0],route[1]);
			players += ({player});
			player->move(ROOT+
				"/gamelib/d/congxianzhen/congxianzhenguangchang");
			set_this_player(player);
			go_command->main(0);
			string destination = file_name(environment(player));
			string links = environment(player)->query_links();
			check(route[0]+"阵营快捷入口抵达可用武阁",
				search(destination,"/gamelib/d/"+route[2])!=-1 &&
				search(links,"[存:user_package]")!=-1 &&
				search(links,"[取:user_repackage]")!=-1,
				"目的地="+destination+" 链接="+links);
		}

		object player = players[0];
		set_this_player(player);
		check("新旧人物都至少拥有免费20格仓库",
			player->query_cangku_size()==20,
			"容量="+player->query_cangku_size());
		player->package_expand = (["cangku":([10:2])]);
		check("扩容仓库使用映射数据并正确计算容量",
			player->query_cangku_size()==40,
			"扩容后容量="+player->query_cangku_size());

		object vip_book = clone(ROOT+"/gamelib/clone/item/book/lingzhen");
		vip_book->set_toVip(1);
		vip_book->move(player);
		object book = clone(ROOT+"/gamelib/clone/item/book/lingzhen");
		string book_name = book->query_name();
		book->move(player);
		store_command->main(book_name+" 0");
		check("同名会员物品不占序号且普通物品可真实存入",
			sizeof(player->packaged_items)==1 &&
			objectp(vip_book) && environment(vip_book)==player &&
			!objectp(book),
			"仓库记录或背包物品状态错误");
		take_command->main(book_name);
		int same_name_count = 0;
		foreach(all_inventory(player),object stored_item){
			if(stored_item->query_name()==book_name)
				same_name_count++;
		}
		check("武阁可把物品真实取回且不复制",
			!sizeof(player->packaged_items) &&
			same_name_count==2,
			"取回后仓库或背包状态错误");
	};
	if(err)
		error_desc = describe_error(err);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("武阁仓库运行态流程无异常",0,error_desc);
	else
		check("武阁仓库运行态流程无异常",1,"");
	foreach(players,object player)
		destroy_player(player);
	werror("[武阁仓库] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
