#!/usr/bin/env pike
/** 挂机入口卡死修复回归：非智能寻路玩家在游戏入口也能路由练级。 */

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
	player->name_cn = "入口路由测试";
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
	object|zero me = 0;
	string error_desc = "";
	mixed err = catch {
		me = create_player("__testunit_entrance__");
		set_this_player(me);

		// 场景1：游戏入口+智能寻路关闭 → 必须路由（修复核心）
		me->move((object)(ROOT+"/gamelib/d/init"));
		me["/plus/autofight_smart_route"] = 0;
		me["/tmp/autofight_last_route_time"] = 0;
		check("入口房+智能关：应当路由（修复前恒0）",
			AUTOFIGHTD->should_route_to_training_area(me)==1,
			"入口卡死未修复");

		// 场景2：入口房+智能开 → 路由（原有行为不回归）
		me["/plus/autofight_smart_route"] = 1;
		check("入口房+智能开：仍路由",
			AUTOFIGHTD->should_route_to_training_area(me)==1,
			"原有智能寻路行为回归");

		// 场景3：普通非菜单房+智能关 → 不路由（开关语义保留）
		me->move((object)(ROOT+"/gamelib/d/bangpai/yanchang"));
		me["/plus/autofight_smart_route"] = 0;
		check("普通房+智能关：不路由（开关语义保留）",
			AUTOFIGHTD->should_route_to_training_area(me)==0,
			"智能开关被整体绕过");

		// 场景4：路由冷却仍生效（入口房不绕过冷却）
		me->move((object)(ROOT+"/gamelib/d/init"));
		me["/tmp/autofight_last_route_time"] = time();
		me["/plus/autofight_smart_route"] = 0;
		check("入口房受路由冷却约束",
			AUTOFIGHTD->should_route_to_training_area(me)==0,
			"冷却被绕过");
	};
	if(err)
		error_desc = describe_error(err);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(error_desc!="")
		check("入口路由流程无异常",0,error_desc);
	else
		check("入口路由流程无异常",1,"");
	destroy_player(me);
	werror("[入口路由] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
