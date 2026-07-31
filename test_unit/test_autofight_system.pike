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
		"/gamelib/cmds/viceskill_dig.pike",
		"/gamelib/cmds/viceskill_gather.pike",
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
			daemon->query_hp_percent(player) == 70 &&
			daemon->query_mana_percent(player) == 50 &&
			daemon->query_loot_enabled(player) == 1 &&
			daemon->query_roam_enabled(player) == 0 &&
			daemon->query_smart_route_enabled(player) == 1 &&
			daemon->query_auto_rest_enabled(player) == 1 &&
			daemon->query_auto_sell_mode(player) == "off" &&
			daemon->query_auto_sell_level_gap(player) == 5 &&
			daemon->query_auto_sell_enabled(player) == 0 &&
			daemon->query_gather_mode(player) == "off" &&
			daemon->query_material_keep(player) == -1 &&
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

void test_vip_auto_sell_tiers()
{
	test_start("VIP等级递进解锁清包品质、触发线和批量数量");
	object player = create_runtime_player(
		"__testunit_autofight_sell_tiers__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		daemon->initialize_player(player);
		player->set_vip_flag(1);
		player["/plus/autofight_auto_sell_mode"] = "normal";
		valid = daemon->query_auto_sell_enabled(player) == 1 &&
			daemon->query_auto_sell_trigger_percent(player) == 100 &&
			daemon->query_auto_sell_batch_size(player) == 1 &&
			daemon->query_auto_sell_mode_requirement("excellent") == 2;

		player->set_vip_flag(2);
		player["/plus/autofight_auto_sell_mode"] = "excellent";
		player["/plus/autofight_sell_level_gap"] = 3;
		valid = valid &&
			daemon->query_auto_sell_enabled(player) == 1 &&
			daemon->query_auto_sell_trigger_percent(player) == 90 &&
			daemon->query_auto_sell_batch_size(player) == 2;

		player->set_vip_flag(3);
		player["/plus/autofight_auto_sell_mode"] = "refined";
		player["/plus/autofight_sell_level_gap"] = 0;
		valid = valid &&
			daemon->query_auto_sell_enabled(player) == 1 &&
			daemon->query_auto_sell_trigger_percent(player) == 80 &&
			daemon->query_auto_sell_batch_size(player) == 4;

		player->set_vip_flag(4);
		valid = valid &&
			daemon->query_auto_sell_trigger_percent(player) == 70 &&
			daemon->query_auto_sell_batch_size(player) == 8;

		player->set_vip_flag(1);
		valid = valid &&
			daemon->query_auto_sell_enabled(player) == 0;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("VIP清包能力分级错误: "+error_desc);
	destroy_runtime_player(player);
}

void test_auto_sell_protection_rules()
{
	test_start("智能清包永久保护珍贵、穿戴、任务和加工装备");
	object player = create_runtime_player(
		"__testunit_autofight_sell_protection__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object item = clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	object gem = clone(ROOT+
		"/gamelib/clone/item/baoshi/psqingtongshi");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		player->level = 30;
		player->set_att_by_level();
		player->set_vip_flag(4);
		daemon->initialize_player(player);
		player["/plus/autofight_auto_sell_mode"] = "refined";
		player["/plus/autofight_sell_level_gap"] = 0;
		item->move(player);
		item->set_item_rareLevel(4);
		valid = daemon->query_auto_sell_reject_reason(player,item) == "";

		item->set_item_rareLevel(5);
		valid = valid &&
			daemon->query_auto_sell_reject_reason(player,item) != "";
		item->set_item_rareLevel(0);
		item->equiped = 1;
		valid = valid &&
			daemon->query_auto_sell_reject_reason(player,item) ==
			"equipped";
		item->equiped = 0;
		item->set_item_task(1);
		valid = valid &&
			daemon->query_auto_sell_reject_reason(player,item) ==
			"task_item";
		item->set_item_task(0);
		item->set_item_from("duanzao");
		valid = valid &&
			daemon->query_auto_sell_reject_reason(player,item) ==
			"special_source";
		item->set_item_from("");
		item->set_convert_count(1);
		valid = valid &&
			daemon->query_auto_sell_reject_reason(player,item) ==
			"converted";
		item->set_convert_count(0);
		item->set_baoshi("blue",gem);
		valid = valid &&
			daemon->query_auto_sell_reject_reason(player,item) ==
			"socketed";
		item->blue_baoshi = ({});
		item->set_item_canTrade(0);
		valid = valid &&
			daemon->query_auto_sell_reject_reason(player,item) ==
			"not_tradeable";
		item->set_item_canTrade(1);
		item->item_playerDesc = "玩家保留";
		valid = valid &&
			daemon->query_auto_sell_reject_reason(player,item) ==
			"player_marked";
		item->item_playerDesc = "";
		item->set_item_canLevel(-1);
		valid = valid &&
			daemon->query_auto_sell_reject_reason(player,item) ==
			"no_level_requirement";
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("自动出售保护规则错误: "+error_desc);
	if(gem)
		destruct(gem);
	destroy_runtime_player(player);
}

void test_auto_sell_settlement()
{
	test_start("智能清包按商店价格结算并只处理允许类别");
	object player = create_runtime_player(
		"__testunit_autofight_sell_settlement__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object weapon = clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	object protected_weapon = clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		player->level = 30;
		player->set_att_by_level();
		player->set_vip_flag(4);
		daemon->initialize_player(player);
		player["/plus/autofight_auto_sell_mode"] = "normal";
		player["/plus/autofight_sell_level_gap"] = 0;
		weapon->move(player);
		protected_weapon->move(player);
		protected_weapon->set_item_task(1);
		player["/plus/autofight_sell_weapon"] = 0;
		valid = daemon->query_auto_sell_reject_reason(player,weapon) ==
			"category";
		player["/plus/autofight_sell_weapon"] = 1;
		int money_before = player->query_account();
		mapping result = daemon->perform_auto_sell(player);
		valid = valid && result["count"] == 1 &&
			result["money"] == 12 &&
			player->query_account() == money_before+12 &&
			environment(protected_weapon) == player &&
			sizeof(all_inventory(player)) == 1;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("自动出售数量、价格或保护对象错误: "+error_desc);
	destroy_runtime_player(player);
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

void test_gathering_and_material_cleanup()
{
	test_start("挂机识别采集物、大堆叠原料并按保留量自动出售");
	object player = create_runtime_player(
		"__testunit_autofight_gathering__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object dig_command = (object)(ROOT+
		"/gamelib/cmds/viceskill_dig.pike");
	object room = clone(ROOT+"/gamelib/d/jinaodao/huangshayuanye");
	object|zero original_player = this_player();
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		foreach(all_inventory(room),object old_item)
			destruct(old_item);
		player->move(room);
		player->vice_skills["caikuang"] = ({0,0,VICESKILL_UP});
		player->vice_skills["caiyao"] = ({0,0,VICESKILL_UP});
		daemon->initialize_player(player);
		player["/plus/autofight_gather_mode"] = "mine";
		object first_ore = clone(ROOT+
			"/gamelib/clone/item/material/tongkuang");
		first_ore->move(room);
		valid = daemon->query_gather_source(player) == first_ore;
		set_this_player(player);
		dig_command->main("tongkuang 0");
		object second_ore = clone(ROOT+
			"/gamelib/clone/item/material/tongkuang");
		second_ore->move(room);
		dig_command->main("tongkuang 0");
		object material = present("tongkuangshi",player);
		valid = valid && material && material->amount >= 2 &&
			material->max_count == 9999;

		object herb = clone(ROOT+
			"/gamelib/clone/item/material/cy_muhudie");
		herb->move(room);
		player["/plus/autofight_gather_mode"] = "herb";
		valid = valid && daemon->query_gather_source(player) == herb;

		material->amount = 350;
		player["/plus/autofight_material_keep"] = 300;
		int money_before = player->query_account();
		mapping sell_result = daemon->perform_auto_sell_material(player);
		valid = valid && sell_result["count"] == 50 &&
			sell_result["money"] == 50 && material->amount == 300 &&
			player->query_account() == money_before+50;
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
		test_fail("自动采集、9999堆叠或原料出售错误: "+error_desc);
	if(room){
		foreach(all_inventory(room),object item)
			if(item != player)
				destruct(item);
		destruct(room);
	}
	destroy_runtime_player(player);
}

void test_recovery_skips_unusable_medicine()
{
	test_start("挂机跳过阵营职业不符药品并回退到可用药");
	object player = create_runtime_player(
		"__testunit_autofight_medicine_limit__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object unusable = clone(ROOT+
		"/gamelib/clone/item/food/xiaohuandan");
	object usable = clone(ROOT+
		"/gamelib/clone/item/food/xinshouhongyao");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		m_delete(unusable->race_limit,"third");
		m_delete(unusable->profe_limit,"fangshi");
		unusable->move(player);
		usable->move(player);
		daemon->initialize_player(player);
		player["/plus/autofight_food"] = "xiaohuandan";
		object selected = daemon->query_recovery_item(player,"life");
		valid = selected == usable;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("不可用药品过滤或自动回退错误: "+error_desc);
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

void test_recovery_selection_checkmarks()
{
	test_start("回血食物和回蓝饮品只勾选当前选择项");
	object player = create_runtime_player(
		"__testunit_autofight_selection__");
	object command = (object)(ROOT+
		"/gamelib/cmds/autofight.pike");
	object red = clone(ROOT+
		"/gamelib/clone/item/food/xinshouhongyao");
	object blue = clone(ROOT+
		"/gamelib/clone/item/water/xinshoulanyao");
	object other_blue = clone(ROOT+
		"/gamelib/clone/item/water/qingquanshui");
	string food_view;
	string water_view;
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		red->move(player);
		blue->move(player);
		other_blue->move(player);
		player["/plus/autofight_food"] = "xinshouhongyao";
		player["/plus/autofight_water"] = "xinshoulanyao";
		food_view = command->view_recovery_items(player,"life");
		water_view = command->view_recovery_items(player,"mana");
		valid = search(food_view,
			"✓ 已选择 [新手回春丹:autofight food xinshouhongyao]") != -1 &&
			search(water_view,
			"✓ 已选择 [新手凝神露:autofight water xinshoulanyao]") != -1 &&
			search(water_view,
			"✓ 已选择 [清泉水:autofight water qingquanshui]") == -1 &&
			sizeof(food_view/"✓ 已选择 ") == 2 &&
			sizeof(water_view/"✓ 已选择 ") == 2;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("恢复物品当前选中标记错误: "+error_desc);
	destroy_runtime_player(player);
}

void test_smart_route_selection()
{
	test_start("全阶段按真实怪物等级和阵营选择练级区");
	object player = create_runtime_player(
		"__testunit_autofight_smart_route__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	array(mapping(string:mixed)) cases = ({
		(["level":1,"race":"human",
			"path":"congxianzhen/shangshanlu","target":1]),
		(["level":8,"race":"monst",
			"path":"jinaodao/wanmuyuan","target":6]),
		(["level":18,"race":"third",
			"path":"shierxianjing/taoyuantongjiuceng",
			"target":17]),
		(["level":35,"race":"human",
			"path":"xiqiwaicheng/huanhuashuitai",
			"target":35]),
		(["level":46,"race":"third",
			"path":"waihai/qianhaiguanmucong",
			"target":44]),
		(["level":49,"race":"monst",
			"path":"fuxishan/fuxidongrukou","target":47]),
		(["level":50,"race":"third",
			"path":"liuguangpingyuan/liuguangchalu",
			"target":50]),
		(["level":54,"race":"human",
			"path":"plxianjing/dangyunshijie","target":53]),
		(["level":57,"race":"monst",
			"path":"plxianjing/binghuanyuntai","target":55]),
		(["level":61,"race":"third",
			"path":"penglaihuanjing/yunyepingyuan",
			"target":60]),
		(["level":63,"race":"human",
			"path":"penglaihuanjing/qiushuangshilu",
			"target":62]),
		(["level":65,"race":"monst",
			"path":"penglaihuanjing/liehuochitang",
			"target":64]),
		(["level":67,"race":"third",
			"path":"klshuanjingwaicheng/heiheyuan",
			"target":66]),
		(["level":69,"race":"human",
			"path":"klshuanjingwaicheng/heishandong",
			"target":68]),
		(["level":70,"race":"third",
			"path":"penglaihuanjing/qiushuangxiaojing",
			"target":70]),
	});
	string error_desc = "";
	int valid = 1;
	mixed err = catch {
		foreach(cases,mapping(string:mixed) one){
			player->level = (int)one["level"];
			player->set_raceId((string)one["race"]);
			mapping route = daemon->query_training_route(player);
			valid = valid &&
				route["path"] == one["path"] &&
				route["level"] == one["target"] &&
				Stdio.exist(ROOT+"/gamelib/d/"+
					(string)route["path"]);
		}
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("智能练级路线、等级或文件路径错误: "+error_desc);
	destroy_runtime_player(player);
}

void test_smart_target_level_window()
{
	test_start("智能模式避开过强和过低怪，手动模式保留旧范围");
	object player = create_runtime_player(
		"__testunit_autofight_target_window__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+"/gamelib/d/jinaodao/huangshayuanye");
	object low;
	object matched;
	object high;
	string error_desc = "";
	int smart_level = 0;
	int manual_level = 0;
	int valid = 0;
	mixed err = catch {
		foreach(all_inventory(room),object old_item)
			destruct(old_item);
		player->move(room);
		low = clone(ROOT+
			"/gamelib/clone/npc/kunlunshan/qinyuan1");
		matched = clone(ROOT+
			"/gamelib/clone/npc/kunlunshan/qinyuan1");
		high = clone(ROOT+
			"/gamelib/clone/npc/kunlunshan/qinyuan1");
		low->_npcLevel = 3;
		matched->_npcLevel = 9;
		high->_npcLevel = 11;
		low->setup_npc_dongtai(player);
		matched->setup_npc_dongtai(player);
		high->setup_npc_dongtai(player);
		low->move(room);
		matched->move(room);
		high->move(room);
		daemon->initialize_player(player);
		player["/plus/autofight_smart_route"] = 1;
		object smart_target = daemon->query_target(player);
		if(smart_target)
			smart_level = smart_target->query_level();
		player["/plus/autofight_smart_route"] = 0;
		object manual_target = daemon->query_target(player);
		if(manual_target)
			manual_level = manual_target->query_level();
		valid = smart_target == matched && manual_target == high;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail(sprintf(
			"怪物等级窗口或目标优先级错误: smart=%d manual=%d %s",
			smart_level,manual_level,error_desc));
	if(room){
		foreach(all_inventory(room),object item)
			if(item != player)
				destruct(item);
		destruct(room);
	}
	destroy_runtime_player(player);
}

void test_real_route_targets()
{
	test_start("46、50、58、69级静态区与70级动态区均有可攻击怪");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object|zero original_player = this_player();
	array(mapping(string:mixed)) cases = ({
		(["name":"__testunit_autofight_route_46__",
			"level":46,
			"path":"waihai/qianhaiguanmucong",
			"target":44]),
		(["name":"__testunit_autofight_route_50__",
			"level":50,
			"path":"liuguangpingyuan/liuguangchalu",
			"target":50]),
		(["name":"__testunit_autofight_route_58__",
			"level":58,
			"path":"plxianjing/binghuanyuntai",
			"target":55]),
		(["name":"__testunit_autofight_route_69__",
			"level":69,
			"path":"klshuanjingwaicheng/heishandong",
			"target":68]),
		(["name":"__testunit_autofight_route_70__",
			"level":70,
			"path":"penglaihuanjing/qiushuangxiaojing",
			"target":70]),
	});
	string error_desc = "";
	int valid = 1;
	foreach(cases,mapping(string:mixed) one){
		object player = create_runtime_player((string)one["name"]);
		object|zero room;
		mixed err = catch {
			player->level = (int)one["level"];
			player->set_att_by_level();
			set_this_player(player);
			room = clone(ROOT+"/gamelib/d/"+(string)one["path"]);
			player->move(room);
			daemon->initialize_player(player);
			player["/plus/autofight_smart_route"] = 1;
			object target = daemon->query_target(player);
			valid = valid && target &&
				target->query_level() == (int)one["target"];
		};
		if(err){
			valid = 0;
			error_desc += sprintf("%d: %s",
				(int)one["level"],describe_error(err));
		}
		if(room){
			foreach(all_inventory(room),object item)
				if(item != player)
					destruct(item);
			destruct(room);
		}
		destroy_runtime_player(player);
	}
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(valid)
		test_pass();
	else
		test_fail("实际练级房间目标等级错误: "+error_desc);
}

void test_auto_rest_safety()
{
	test_start("缺药休整只离开普通地图并使用阵营安全休息点");
	object player = create_runtime_player(
		"__testunit_autofight_rest__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+"/gamelib/d/jinaodao/huangshayuanye");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		player->move(room);
		daemon->initialize_player(player);
		valid = daemon->query_rest_room(player) ==
			"congxianzhen/congxianzhenguangchang" &&
			daemon->begin_auto_rest(player) == 1 &&
			daemon->query_is_resting(player) == 1;
		daemon->finish_auto_rest(player);
		room->set_room_type("fb");
		valid = valid &&
			daemon->can_auto_leave_current_room(player) == 0 &&
			daemon->begin_auto_rest(player) == 0;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("休息点、休整状态或特殊地图保护错误: "+error_desc);
	if(room){
		foreach(all_inventory(room),object item)
			if(item != player)
				destruct(item);
		destruct(room);
	}
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
		daemon->initialize_player(player);
		player["/plus/autofight_smart_route"] = 0;
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

void test_end_to_end_smart_route_fight()
{
	test_start("游戏环境中自动换到同级练级区并开始战斗");
	object player = create_runtime_player(
		"__testunit_autofight_smart_e2e__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+"/gamelib/d/jinaodao/huangshayuanye");
	object flush_command = (object)(ROOT+
		"/lowlib/wapmud2/cmds/flushview.pike");
	object|zero original_player = this_player();
	string error_desc = "";
	string route_path = "";
	string second_path = "";
	string selected_name = "";
	int enemy_level = 0;
	int selected_level = 0;
	int player_level = 0;
	int life_percent = 0;
	int mana_percent = 0;
	int resting = 0;
	int was_in_combat = 0;
	int valid = 0;
	mixed err = catch {
		player->move(room);
		set_this_player(player);
		daemon->initialize_player(player);
		player["/plus/autofight_smart_route"] = 1;
		player["/plus/autofight_auto_rest"] = 1;
		daemon->start_autofight(player);
		flush_command->main(0);
		route_path = daemon->query_current_room_path(player);
		object selected = daemon->query_target(player);
		if(selected){
			selected_name = selected->query_name();
			selected_level = selected->query_level();
		}
		player_level = player->query_level();
		life_percent = player->get_cur_life()*100/
			player->query_life_max();
		mana_percent = player->get_cur_mofa()*100/
			player->query_mofa_max();
		flush_command->main(0);
		second_path = daemon->query_current_room_path(player);
		resting = daemon->query_is_resting(player);
		if(player->query_enemy())
			enemy_level = player->query_enemy()->query_level();
		was_in_combat = player->in_combat;
		valid = route_path == "mihuandao/nongwusenlin" &&
			player->in_combat && player->query_enemy() &&
			player->query_enemy()->is("npc") &&
			player->query_enemy()->query_level() >= 6 &&
			player->query_enemy()->query_level() <= 10;
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
		test_fail(sprintf(
			"智能换区或自动开战完整链路错误: first=%s second=%s player=%d selected=%s/%d life=%d mana=%d resting=%d combat=%d enemy=%d %s",
			route_path,second_path,player_level,
			selected_name,selected_level,
			life_percent,mana_percent,resting,
			was_in_combat,enemy_level,error_desc));
	if(room){
		foreach(all_inventory(room),object item)
			if(item != player)
				destruct(item);
		destruct(room);
	}
	destroy_runtime_player(player);
}

void test_end_to_end_auto_rest()
{
	test_start("游戏环境中缺药时自动回安全点并睡眠恢复");
	object player = create_runtime_player(
		"__testunit_autofight_rest_e2e__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+"/gamelib/d/jinaodao/huangshayuanye");
	object flush_command = (object)(ROOT+
		"/lowlib/wapmud2/cmds/flushview.pike");
	object|zero original_player = this_player();
	string error_desc = "";
	string rest_path = "";
	int valid = 0;
	mixed err = catch {
		foreach(all_inventory(player),object item)
			destruct(item);
		player->level = 31;
		player->set_att_by_level();
		player->set_life(1);
		player->set_mofa(1);
		player->move(room);
		set_this_player(player);
		daemon->initialize_player(player);
		player["/plus/autofight_smart_route"] = 1;
		player["/plus/autofight_auto_rest"] = 1;
		player["/plus/autofight_loot"] = 0;
		daemon->start_autofight(player);
		flush_command->main(0);
		rest_path = daemon->query_current_room_path(player);
		valid = rest_path ==
			"congxianzhen/congxianzhenguangchang" &&
			daemon->query_is_resting(player) == 1 &&
			player->query_autofight() == "enable";
		flush_command->main(0);
		valid = valid &&
			player->get_cur_life() == player->query_life_max() &&
			player->get_cur_mofa() == player->query_mofa_max();
		daemon->stop_autofight(player);
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
		test_fail("自动返程、睡眠或恢复完整链路错误: path="+
			rest_path+" "+error_desc);
	if(room){
		foreach(all_inventory(room),object item)
			if(item != player)
				destruct(item);
		destruct(room);
	}
	destroy_runtime_player(player);
}

void test_end_to_end_auto_sell()
{
	test_start("游戏挂机循环在VIP4阈值自动批量清包并继续运行");
	object player = create_runtime_player(
		"__testunit_autofight_sell_e2e__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+"/gamelib/d/jinaodao/huangshayuanye");
	object flush_command = (object)(ROOT+
		"/lowlib/wapmud2/cmds/flushview.pike");
	object|zero original_player = this_player();
	string error_desc = "";
	int before_count = 0;
	int after_count = 0;
	int valid = 0;
	mixed err = catch {
		player->level = 30;
		player->set_att_by_level();
		player->set_vip_flag(4);
		player->move(room);
		set_this_player(player);
		daemon->initialize_player(player);
		player["/plus/autofight_auto_sell_mode"] = "normal";
		player["/plus/autofight_sell_level_gap"] = 0;
		player["/plus/autofight_smart_route"] = 0;
		while(daemon->query_backpack_percent(player) < 70){
			object item = clone(ROOT+
				"/gamelib/clone/item/weapon/1taomujian/1taomujian");
			item->move(player);
		}
		before_count = sizeof(all_inventory(player));
		daemon->start_autofight(player);
		flush_command->main(0);
		after_count = sizeof(all_inventory(player));
		valid = before_count-after_count == 8 &&
			player->query_autofight() == "enable" &&
			!player->in_combat;
		daemon->stop_autofight(player);
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
		test_fail(sprintf(
			"挂机自动清包完整链路错误: before=%d after=%d %s",
			before_count,after_count,error_desc));
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
	string autofight_source = Stdio.read_file(
		ROOT+"/gamelib/cmds/autofight.pike");
	string flush_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/cmds/flushview.pike");
	if(api_source && renderer_source && vue_source && index_source &&
	   daily_source && kill_source && leave_source && user_source &&
	   autofight_source && flush_source &&
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
	   search(user_source,"autofight") != -1 &&
	   search(daily_source,"AUTOFIGHTD->reset_daily_time(me)") != -1 &&
	   search(kill_source,"query_autofight()==\"disable\"") != -1 &&
	   search(leave_source,"query_autofight()==\"disable\"") != -1 &&
	   search(autofight_source,"高级清包设置") != -1 &&
	   search(autofight_source,"永久保护") != -1 &&
	   search(flush_source,"perform_auto_sell(me)") != -1)
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
	test_vip_auto_sell_tiers();
	test_auto_sell_protection_rules();
	test_auto_sell_settlement();
	test_time_and_low_life_guard();
	test_gathering_and_material_cleanup();
	test_recovery_skips_unusable_medicine();
	test_duplicate_object_count();
	test_recovery_selection_checkmarks();
	test_smart_route_selection();
	test_smart_target_level_window();
	test_real_route_targets();
	test_auto_rest_safety();
	test_end_to_end_current_room_fight();
	test_end_to_end_smart_route_fight();
	test_end_to_end_auto_rest();
	test_end_to_end_auto_sell();
	test_integration_wiring();
	werror("\n自动挂机测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"] == 0 ? 0 : 1;
}
