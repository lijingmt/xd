#!/usr/bin/env pike
/**
 * 自动打怪／挂机测试：
 * 运行时编译 -> 玩家默认值 -> 开关与计时 ->
 * 低血保护与药品选择 -> 同名对象计数 -> API/Vue/每日重置接线。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total":0,
	"passed":0,
	"failed":0,
]);

void test_start(string name)
{
	test_results["total"]++;
	werror("\n[自动挂机 %d] %s\n",test_results["total"],name);
}

void test_pass()
{
	test_results["passed"]++;
	werror("  ✓ 通过\n");
}

void test_fail(string reason)
{
	test_results["failed"]++;
	werror("  ✗ 失败: %s\n",reason);
}

object create_runtime_player(string player_name)
{
	object player;
	player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(player_name);
	player->name_cn = "自动挂机测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->level = 10;
	player->set_att_by_level();
	return player;
}

void destroy_runtime_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

void test_runtime_compile()
{
	test_start("守护进程与三个命令运行时编译");
	array(string) paths = ({
		"/gamelib/single/daemons/autofightd.pike",
		"/gamelib/cmds/autofight.pike",
		"/gamelib/cmds/autofightclose.pike",
		"/lowlib/wapmud2/cmds/flushview.pike",
	});
	int failed = 0;
	string error_desc = "";
	foreach(paths,string path){
		mixed err = catch {
			program compiled = (program)(ROOT+path);
			if(!compiled)
				failed++;
		};
		if(err){
			failed++;
			error_desc += path+": "+describe_error(err);
		}
	}
	if(failed == 0)
		test_pass();
	else
		test_fail("自动挂机文件编译失败: "+error_desc);
}

void test_defaults_and_switch()
{
	test_start("默认安全设置、每日时长与开关状态");
	object player = create_runtime_player("__testunit_autofight_state__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		daemon->initialize_player(player);
		valid = daemon->query_daily_seconds() == 8*60*60 &&
			daemon->query_time_left(player) == 8*60*60 &&
			daemon->query_hp_percent(player) == 50 &&
			daemon->query_mana_percent(player) == 30 &&
			daemon->query_loot_enabled(player) == 1 &&
			daemon->query_roam_enabled(player) == 0 &&
			player->query_autofight() == "disable";
		daemon->start_autofight(player);
		valid = valid && player->query_autofight() == "enable";
		daemon->stop_autofight(player);
		valid = valid && player->query_autofight() == "disable";
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("默认值或开关错误: "+error_desc);
	destroy_runtime_player(player);
}

void test_vip_daily_limits()
{
	test_start("VIP1至VIP4每日额度、当天升级与降级同步");
	object normal_player = create_runtime_player(
		"__testunit_autofight_normal_limit__");
	object vip_player = create_runtime_player(
		"__testunit_autofight_vip_limit__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		daemon->initialize_player(normal_player);
		normal_player["/plus/autofight_time_left"] = 7*60*60;
		normal_player->set_vip_flag(1);
		valid = daemon->query_daily_seconds_for(normal_player) == 10*60*60 &&
			daemon->query_time_left(normal_player) == 9*60*60;
		normal_player->set_vip_flag(4);
		valid = valid &&
			daemon->query_daily_seconds_for(normal_player) == 16*60*60 &&
			daemon->query_time_left(normal_player) == 15*60*60;
		normal_player->set_vip_flag(0);
		valid = valid &&
			daemon->query_daily_seconds_for(normal_player) == 8*60*60 &&
			daemon->query_time_left(normal_player) == 7*60*60;

		vip_player->set_vip_flag(4);
		daemon->initialize_player(vip_player);
		valid = valid &&
			daemon->query_time_left(vip_player) == 16*60*60;
		vip_player["/plus/autofight_time_left"] = 1;
		daemon->reset_daily_time(vip_player);
		valid = valid &&
			daemon->query_time_left(vip_player) == 16*60*60;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("VIP挂机额度同步错误: "+error_desc);
	destroy_runtime_player(normal_player);
	destroy_runtime_player(vip_player);
}

void test_time_and_low_life_guard()
{
	test_start("计时扣减、低血判断与回血食物自动选择");
	object player = create_runtime_player("__testunit_autofight_guard__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object food = clone(ROOT+"/gamelib/clone/item/food/1lifemofa");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		daemon->initialize_player(player);
		food->move(player);
		player->set_life(player->query_life_max()/4);
		player["/tmp/autofight_last_charge"] = time()-5;
		int before = daemon->query_time_left(player);
		int after = daemon->charge_time(player);
		object selected = daemon->query_recovery_item(player,"life");
		valid = after <= before-5 &&
			daemon->should_recover_life(player) &&
			selected == food;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("计时或低血保护错误: "+error_desc);
	destroy_runtime_player(player);
}

void test_duplicate_object_count()
{
	test_start("同名堆叠物品序号与自动拾取命令参数一致");
	object player = create_runtime_player("__testunit_autofight_count__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object first = clone(ROOT+"/gamelib/clone/item/food/ganliang");
	object second = clone(ROOT+"/gamelib/clone/item/food/ganliang");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		first->move(player);
		second->move(player);
		valid = daemon->query_object_count(first,player) == 0 &&
			daemon->query_object_count(second,player) == 1;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("同名对象序号错误: "+error_desc);
	destroy_runtime_player(player);
}

void test_end_to_end_current_room_fight()
{
	test_start("游戏环境中启动挂机并自动攻击当前地图怪物");
	object player = create_runtime_player("__testunit_autofight_e2e__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+"/gamelib/d/jinaodao/huangshayuanye");
	object flush_command = (object)(ROOT+
		"/lowlib/wapmud2/cmds/flushview.pike");
	object|zero original_player = this_player();
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		player->move(room);
		set_this_player(player);
		daemon->start_autofight(player);
		flush_command->main(0);
		valid = player->query_autofight() == "enable" &&
			player->in_combat && player->query_enemy() &&
			player->query_enemy()->is("npc") &&
			environment(player->query_enemy()) == room;
		daemon->stop_autofight(player);
		player->_clean_fight();
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("自动攻击完整链路错误: "+error_desc);
	if(room){
		foreach(all_inventory(room),object item)
			if(item != player)
				destruct(item);
		destruct(room);
	}
	destroy_runtime_player(player);
}

void test_integration_wiring()
{
	test_start("HTTP状态、前端入口、防重入与每日重置完整接线");
	string api_source = Stdio.read_file(
		ROOT+"/gamelib/single/daemons/http_api_daemon.pike");
	string renderer_source = Stdio.read_file(
		ROOT+"/gamelib/single/daemons/_http_api_mod/html_renderer.pike");
	string vue_source = Stdio.read_file(ROOT+"/vue_source/js/app.js");
	string index_source = Stdio.read_file(ROOT+"/vue_source/index.html");
	string daily_source = Stdio.read_file(
		ROOT+"/gamelib/single/daemons/userd.pike");
	string kill_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/cmds/kill.pike");
	string leave_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/cmds/leave.pike");
	string user_source = Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	if(api_source && renderer_source && vue_source && index_source &&
	   daily_source && kill_source && leave_source && user_source &&
	   search(api_source,"AUTOFIGHTD->start_autofight(player)") != -1 &&
	   search(renderer_source,"result[\"autofight_time_left\"]") != -1 &&
	   search(renderer_source,"result[\"autofight_daily_limit\"]") != -1 &&
	   search(vue_source,"autofightTickInFlight") != -1 &&
	   search(vue_source,"runAutofightTick") != -1 &&
	   search(vue_source,"isAutofightRefresh") != -1 &&
	   search(vue_source,"await this.checkBattleStatus(isAutofightRefresh)") != -1 &&
	   search(vue_source,"seg.label.includes('关闭自动挂机')") != -1 &&
	   search(vue_source,"battleStatusLoading") != -1 &&
	   search(vue_source,"this.isInBattle = true") != -1 &&
	   search(index_source,"挂机设置") != -1 &&
	   search(user_source,"[自动打怪／挂机:autofight open]") != -1 &&
	   search(user_source,"[停止自动挂机:autofightclose]") != -1 &&
	   search(daily_source,"AUTOFIGHTD->reset_daily_time(me)") != -1 &&
	   search(kill_source,"query_autofight()==\"disable\"") != -1 &&
	   search(leave_source,"query_autofight()==\"disable\"") != -1)
		test_pass();
	else
		test_fail("API、Vue、每日重置或防外挂豁免缺少接线");
}

int main()
{
	werror("\n========== 自动打怪／挂机系统测试 ==========\n");
	test_runtime_compile();
	test_defaults_and_switch();
	test_vip_daily_limits();
	test_time_and_low_life_guard();
	test_duplicate_object_count();
	test_end_to_end_current_room_fight();
	test_integration_wiring();
	werror("\n自动挂机测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"] == 0 ? 0 : 1;
}
