#!/usr/bin/env pike
/** 管理后台物品发放：路径校验、原子存档、幂等与多Worker路由契约。 */

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

int inventory_template_count(object player,string template_path)
{
	int count;
	foreach(all_inventory(player),object item){
		string path = file_name(item);
		sscanf(path,"%s#%*d",path);
		if(path==template_path)
			count += functionp(item->is_combine_item) &&
				item->is_combine_item() ? (int)item->amount : 1;
	}
	return count;
}

int main()
{
	string userid = "xd99itemgrant99";
	string suiyu_path = ROOT+"/gamelib/clone/item/yushi/suiyu";
	string box_path = ROOT+
		"/gamelib/clone/item/baoxiang/jingjinbaoxiang";
	string request_id = ACCOUNT_WALLETD->new_recharge_request_id();
	string box_request_id = ACCOUNT_WALLETD->new_recharge_request_id();
	string expired_id = sprintf("%010d",1)+
		String.string2hex(Crypto.Random.random_string(27));
	object original_player = this_player();
	object|zero player = 0;
	object|zero verifier = 0;
	object command_ob = (object)(ROOT+"/gamelib/cmds/mgr_give_item.pike");
	check("后台发物品保留历史人物ID精确大小写",
		command_ob->valid_admin_item_userid("xd01LSQ2026") &&
		!command_ob->valid_admin_item_userid("xd01LSQ/2026"),
		"大写人物ID被误拒绝或路径字符被放行");
	string gateway = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/pike_gateway.pike") || "";
	string rpc = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike") || "";
	string cluster = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/map_workerd.pike") || "";
	string httpd = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike") || "";
	string error_desc = "";
	werror("\n========== 管理后台物品发放测试 ==========\n");
	cleanup_player(userid);
	mixed err = catch {
		check("非法路径和不存在物品失败关闭",
			!command_ob->inspect_admin_item("../clone/user",1)["ok"] &&
			!command_ob->inspect_admin_item("not/existing/item",1)["ok"],
			"路径穿越或不存在程序通过物品校验");
		mapping preview = command_ob->inspect_admin_item("yushi/suiyu",75);
		check("复数物品按最大堆叠数拆分且对象数有上限",
			preview["ok"] && preview["combine"] &&
			preview["object_count"]>=1 && preview["object_count"]<=100,
			"复数物品预检未得到安全对象数量");
		check("不落盘物品和批量唯一装备不会进入发放流程",
			!command_ob->inspect_admin_item("water/tianshanganlu",1)["ok"] &&
			!command_ob->inspect_admin_item("weapon/69hanbingshuangjian",2)["ok"],
			"重启即消失的物品或唯一装备可被批量发放");

		player = clone(GAMELIB_USER);
		player->set_name(userid);
		player->set_project("gamelib");
		player->setup("testunit-admin-item");
		player->name_cn = "后台发物测试人物";
		player->set_raceId("third");
		player->set_profeId("fangshi");
		player->setup_player("third","fangshi");
		player->save_with_result(0,1);
		check("未建分职业索引的旧玩家档案仍可作为发放目标",
			command_ob->admin_item_target_exists(userid),
			"后台目标校验不兼容历史单人物账号");
		mixed denied_err = catch {
			set_this_player(player);
			command_ob->main(""+userid+" yushi/suiyu 1 "+request_id);
		};
		if(original_player)
			set_this_player(original_player);
		else
			set_this_player(this_object());
		check("普通玩家不能调用后台物品发放入口",
			!denied_err && inventory_template_count(player,suiyu_path)==0,
			"非管理员通过主命令改变了背包");

		mapping first = command_ob->execute_admin_item_grant_target(player,
			"yushi/suiyu",75,"testunitadmin",request_id,1);
		mapping repeated = command_ob->execute_admin_item_grant_target(player,
			"yushi/suiyu",75,"testunitadmin",request_id,1);
		mapping conflict = command_ob->execute_admin_item_grant_target(player,
			"yushi/suiyu",76,"testunitadmin",request_id,1);
		check("同一确认链接只发放一次且禁止改参数复用",
			first["ok"] && !first["duplicate"] && repeated["ok"] &&
			repeated["duplicate"] && !conflict["ok"] &&
			inventory_template_count(player,suiyu_path)==75,
			"重复请求克隆物品或同一凭据可被换物复用");

		mapping box = command_ob->execute_admin_item_grant_target(player,
			"baoxiang/jingjinbaoxiang",2,"testunitadmin",box_request_id,1);
		mapping expired = command_ob->execute_admin_item_grant_target(player,
			"yushi/suiyu",1,"testunitadmin",expired_id,1);
		check("非堆叠装备道具逐件发放且过期链接不补发",
			box["ok"] && inventory_template_count(player,box_path)==2 &&
			!expired["ok"] && inventory_template_count(player,suiyu_path)==75,
			"非堆叠数量或过期请求处理错误");

		player->discard_stale_worker_copy();
		player = 0;
		verifier = clone(GAMELIB_USER);
		verifier->set_name(userid);
		verifier->set_project("gamelib");
		int restored = verifier->restore();
		mapping receipt = verifier->query_admin_item_grant_receipt(request_id);
		check("物品与幂等凭据在唯一玩家档案中原子重载",
			restored && receipt["item_path"]=="yushi/suiyu" &&
			receipt["item_count"]==75 &&
			inventory_template_count(verifier,suiyu_path)==75 &&
			inventory_template_count(verifier,box_path)==2,
			"重载后物品数量或凭据不一致");
		int receipt_fill_ok = 1;
		for(int receipt_index=0;receipt_index<254;receipt_index++){
			string fill_id = ACCOUNT_WALLETD->new_recharge_request_id();
			if(!verifier->record_admin_item_grant_receipt(fill_id,
				"yushi/suiyu",1))
				receipt_fill_ok = 0;
		}
		string overflow_id = ACCOUNT_WALLETD->new_recharge_request_id();
		check("幂等凭据达到上限时拒绝新发放且不淘汰仍有效凭据",
			receipt_fill_ok &&
			!verifier->record_admin_item_grant_receipt(overflow_id,
				"yushi/suiyu",1) &&
			sizeof(verifier->query_admin_item_grant_receipt(request_id)),
			"高频发放可能淘汰新鲜凭据并让旧确认链接重复克隆");

		check("多Worker后台发物使用双账号锁和目标Worker能力凭据",
			search(gateway,"pike_gateway_admin_item_grant_target")!=-1 &&
			search(gateway,"pike_gateway_lock_user_pair")!=-1 &&
			search(gateway,"admin_item_grant|")!=-1 &&
			search(rpc,"execute_map_worker_admin_item_grant")!=-1 &&
			search(rpc,"local_admin_item_grant")!=-1 &&
			search(rpc,"target_worker==MAP_WORKERD->query_local_worker_id()")!=-1 &&
			search(cluster,"admin_item_request_id")!=-1 &&
			search(httpd,"x-xiand-admin-item-request")!=-1,
			"跨Worker精确路由、加锁或能力凭据链不完整");

		string command_source = Stdio.read_file(ROOT+
			"/gamelib/cmds/mgr_give_item.pike") || "";
		string menu_source = Stdio.read_file(ROOT+
			"/gamelib/cmds/game_deal.pike") || "";
		check("后台入口受管理员权限保护并写独立审计日志",
			search(command_source,"MANAGERD->checkpower")!=-1 &&
			search(command_source,"manage_give_item.log")!=-1 &&
			search(menu_source,"给指定玩家发放物品")!=-1,
			"普通玩家可能调用入口或管理员操作无法审计");
	};
	if(err)
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
	if(err)
		check("测试运行无异常",0,error_desc);
	if(player)
		player->discard_stale_worker_copy();
	if(verifier)
		verifier->discard_stale_worker_copy();
	cleanup_player(userid);
	werror("管理后台物品发放：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
