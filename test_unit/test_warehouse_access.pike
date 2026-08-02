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
				search(links,"[背包存入:user_package]")!=-1 &&
				search(links,"[取到背包:user_repackage]")!=-1 &&
				search(links,"[账号共享仓库:account_storage]")!=-1,
				"目的地="+destination+" 链接="+links);
		}

		object player = players[0];
		set_this_player(player);
		array(string) wuge_files = ({
			"/gamelib/d/kunlunshan/wuge",
			"/gamelib/d/jinaodao/wuge",
			"/gamelib/d/plxianjing/wuge1",
			"/gamelib/d/plxianjing/wuge2",
			"/gamelib/d/jadhuanjing/wuge",
			"/gamelib/d/klshuanjing/wuge",
		});
		int wuge_ui_ok = 1;
		for(int room_index=0;room_index<sizeof(wuge_files);room_index++){
			string source = Stdio.read_file(ROOT+wuge_files[room_index]);
			mixed compile_err = catch{
				compile_file(ROOT+wuge_files[room_index]);
			};
			if(compile_err || !source ||
			   search(source,"当前角色仓库")<0 ||
			   search(source,"账号共享仓库")<0)
				wuge_ui_ok = 0;
		}
		check("全部六座武阁使用相同且清晰的仓库名称",
			wuge_ui_ok,
			"仍有武阁缺少角色仓库或账号共享仓库入口");

		string shared_ui =
			Stdio.read_file(ROOT+"/gamelib/cmds/account_storage.pike");
		string deposit_ui =
			Stdio.read_file(ROOT+
				"/gamelib/cmds/account_storage_deposit.pike");
		string withdraw_ui =
			Stdio.read_file(ROOT+
				"/gamelib/cmds/account_storage_withdraw.pike");
		string batch_ui =
			Stdio.read_file(ROOT+
				"/gamelib/cmds/account_storage_batch.pike");
		check("共享仓库按操作方向分页且转移后停留在当前列表",
			shared_ui && deposit_ui && withdraw_ui && batch_ui &&
			search(shared_ui,"背包 ↔ 当前角色仓库 ↔ 账号共享仓库")!=-1 &&
			search(shared_ui,"STORAGE_PAGE_SIZE 8")!=-1 &&
			search(shared_ui,"放入共享：角色仓库 → 账号共享")!=-1 &&
			search(shared_ui,"取给角色：账号共享 → 角色仓库")!=-1 &&
			search(deposit_ui,"account_storage put ")!=-1 &&
			search(withdraw_ui,"account_storage take ")!=-1,
			"操作方向、分页或连续操作入口缺失");
		check("共享仓库把物品和操作按钮组合显示并分隔条目",
			shared_ui &&
			search(shared_ui,"s += \"• \"+personal[i][2]+\" \";")!=-1 &&
			search(shared_ui,"s += \"• \"+data[2]+\" \";")!=-1 &&
			search(shared_ui,"s += \"────────────\\n\";")!=-1,
			"物品与按钮仍分行显示或条目分隔线缺失");
		check("共享仓库本页批量操作限制八件并拦截重复点击",
			shared_ui && batch_ui &&
			search(shared_ui,"本页全部放入（")!=-1 &&
			search(shared_ui,"本页全部取回（")!=-1 &&
			search(shared_ui,"同名装备保留各自属性")!=-1 &&
			search(batch_ui,"STORAGE_PAGE_SIZE 8")!=-1 &&
			search(batch_ui,"expected_token!=account_storage_batch_token")!=-1 &&
			search(batch_ui,"重复或过期操作已拦截")!=-1,
			"批量入口、八件上限或防重复令牌缺失");

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
