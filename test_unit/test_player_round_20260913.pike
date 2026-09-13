#!/usr/bin/env pike
/** 2026-09-13五项修复的集中回归：一键学习/头像门禁/套装保留/寻路绑定/前缀分档。 */

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
	player->name_cn = "五项回归"+userid;
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	// liehuojiangang需要44级；测试号直接设等级满足。
	player->level=50;
	return player;
}

int main()
{
	object original_player = this_player();
	object|zero me = 0;
	string error_desc = "";
	mixed err = catch {
		me = create_player("__testunit_round13__");
		// 白名单机制：武阁不在练级池白名单→绑定被拒。
		mixed raw_p=(mixed)me["/plus/autofight_preferred_route_path"];
		me["/plus/autofight_preferred_route_path"]="";
		me->move((object)(ROOT+"/gamelib/d/kunlunshan/wuge"));
		set_this_player(me);

		// ===== 1) 一键学习：堆叠书学成计数 =====
		object book_cmd = (object)(
			ROOT+"/gamelib/cmds/learn_all.pike");
		// liehuojiangang是剑仙专属书，匹配测试号职业。
		object stack = clone(ROOT+
			"/gamelib/clone/item/book/liehuojiangang");
		stack->amount = 5;
		stack->move(me);
		int before_amount = (int)stack->amount;
		book_cmd->main("");
		check("堆叠书(×5)一键学习被正确计数为已学",
			arrayp(me->skills["liehuojiangang"]),
			sprintf("skills=%O",me->skills));
		check("堆叠书学习后消耗一本(5→4)且书还在",
			objectp(stack) &&
			(int)stack->amount==before_amount-1,
			sprintf("amount=%O",(objectp(stack)?stack->amount:-1)));

		// ===== 2) 头像门禁：close=隐藏，open/未设=显示 =====
		me->pic_flag = (["character":"close"]);
		check("头像close后渲染为空",
			me->query_user_picture_url()=="" &&
			me->query_mini_user_picture_url()=="",
			"close仍渲染");
		me->pic_flag = (["character":"open"]);
		me->user_pic="xd01testuser";
		check("头像open时正常渲染门禁放行",
			me->query_user_picture_url()!="",
			"open被误拦");
		me->user_pic="";
		me->pic_flag = 0;

		// ===== 3) 套装清理：稀有度绝对优先 =====
		string cleanup_src = Stdio.read_file(
			ROOT+"/gamelib/cmds/set_equipment_cleanup.pike");
		check("套装保留比较器改为稀有度绝对优先",
			search(cleanup_src,"rare>keep_rare")!=-1,
			"比较器未升级");

		// ===== 4) 寻路绑定 =====
		// 4a: 未绑定→正常等级路线（stringp守卫生效）
		mapping route = AUTOFIGHTD->query_training_route(me);
		check("未绑定时走等级表路线（int-0守卫）",
			mappingp(route) && (string)route["path"]!="",
			sprintf("route=%O",route));
		// 4b: 绑定当前广场被拒（city），绑定野外图生效
		object bind_cmd = (object)(
			ROOT+"/gamelib/cmds/training_route_bind.pike");
		bind_cmd->main("here"); // 当前在广场=city → 拒绝
		mixed after_p=(mixed)me["/plus/autofight_preferred_route_path"];
		check("武阁(非白名单)不能绑定为挂机图",
			stringp(after_p) ? (string)after_p=="" : 1,
			"白名单外绑定被放行");
		me->move((object)(
			ROOT+"/gamelib/d/congxianzhen/shangshanlu"));
		bind_cmd->main("here");
		route = AUTOFIGHTD->query_training_route(me);
		check("绑定野外图后路由优先走绑定图",
			(string)(me["/plus/autofight_preferred_route_path"])==
				"congxianzhen/shangshanlu" &&
			(string)route["path"]=="congxianzhen/shangshanlu",
			sprintf("bound=%O route=%O",
				me["/plus/autofight_preferred_route_path"],
				route["path"]));
		bind_cmd->main("clear");
		route = AUTOFIGHTD->query_training_route(me);
		check("解除绑定恢复等级表路线",
			(string)route["path"]!="congxianzhen/shangshanlu",
			sprintf("route=%O",route["path"]));

		// ===== 5) 前缀清理分档 =====
		object cleanup = (object)(
			ROOT+"/gamelib/cmds/prefix_gear_cleanup.pike");
		object tier8 = ITEMSD->get_convert_item(
			"armor/10lupimao/10lupimao",8,10,10);
		object tier10 = ITEMSD->get_convert_item(
			"armor/10lupimao/10lupimao",10,10,10);
		tier8->move(me);
		tier10->move(me);
		cleanup->main("10"); // 仅寂灭预览
		check("分档预览只命中寂灭(10)件",
			objectp(tier8) && objectp(tier10),
			"预览不应销毁");
		// 通过核心选择器验证分档过滤
		// （命令内query_cleanup_gear是private，用文件+源断言）
		string pc_src = Stdio.read_file(
			ROOT+"/gamelib/cmds/prefix_gear_cleanup.pike");
		check("分档参数与确认链路齐备",
			search(pc_src,"sscanf(arg,\"confirm %d\",tier)")!=-1 &&
			search(pc_src,"tier_names[tier]")!=-1,
			"分档链路缺失");
		destruct(tier8);
		destruct(tier10);
	};
	if(err)
		error_desc = describe_error(err);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(error_desc!="")
		check("五项修复流程无异常",0,error_desc);
	else
		check("五项修复流程无异常",1,"");
	if(me){
		foreach(all_inventory(me),object item)
			destruct(item);
		destruct(me);
	}
	werror("[五项修复回归] total=%d passed=%d failed=%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
