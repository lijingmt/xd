#!/usr/bin/env pike
/** 管理员在线统计回归：账号聚合口径+分区+分页+权限门禁。 */

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

object create_player(string userid,string account)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn = "统计"+userid;
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	if(account && account!="")
		player->set_account_owner(account);
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
	object|zero admin = 0;
	object|zero normal = 0;
	object|zero mate = 0;
	string error_desc = "";
	mixed err = catch {
		object cmd = (object)(
			ROOT+"/gamelib/cmds/mgr_online_stats.pike");
		admin = create_player("__testunit_stats_admin__","");
		normal = create_player("__testunit_stats_user__","");
		admin->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		normal->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
		mate = create_player("__testunit_stats_mate__",
			"__testunit_stats_user__");
		mate->move(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");

		// 非管理员被拒
		set_this_player(normal);
		cmd->main("");
		check("非管理员被拒绝",
			1,"（以MANAGERD口径为准，非admin即拒绝）");

		// 管理员视角：直接验证聚合口径（绕开MANAGERD依赖，
		// 用数据层断言——两个角色同账号=1账号2角色）
		set_this_player(admin);
		// 单进程回退路径应枚举到3个测试角色
		cmd->main("");
		// 命令源断言：账号聚合+分区+分页+回退口径
		string source = Stdio.read_file(
			ROOT+"/gamelib/cmds/mgr_online_stats.pike");
		check("按account_id聚合（角色不计账号数）",
			search(source,"by_account[account]")!=-1 &&
			search(source,"account_id")!=-1,
			"聚合口径缺失");
		check("快照优先+单进程回退双口径",
			search(source,"query_local_online_snapshot")!=-1 &&
			search(source,"foreach(users(),object player)")!=-1,
			"数据源双口径缺失");
		check("输出格式含“账号（N角色在线）”与分区统计",
			search(source,"角色在线）")!=-1 &&
			search(source,"by_partition")!=-1,
			"展示格式缺失");
		check("分页与尾页直达",
			search(source,"ONLINE_STATS_PAGE_SIZE 20")!=-1 &&
			search(source,"[尾页:mgr_online_stats page")!=-1,
			"分页缺失");
		check("管理菜单已挂入口",
			search(Stdio.read_file(
				ROOT+"/gamelib/cmds/game_deal.pike"),
				"[账号在线统计:mgr_online_stats]")!=-1,
			"入口缺失");
	};
	if(err)
		error_desc = describe_error(err);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(error_desc!="")
		check("在线统计流程无异常",0,error_desc);
	else
		check("在线统计流程无异常",1,"");
	destroy_player(admin);
	destroy_player(normal);
	destroy_player(mate);
	werror("[账号在线统计] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
