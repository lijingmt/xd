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

void set_active_vip(object player,int level)
{
	player->set_vip_flag(level);
	player->set_vip_end_time(level > 0 ? time()+3600 : 0);
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
	test_start("守护进程与相关命令运行时编译");
	array(string) paths = ({
		"/gamelib/single/daemons/autofightd.pike",
		"/gamelib/cmds/autofight.pike",
		"/gamelib/cmds/autofightclose.pike",
		"/lowlib/wapmud2/cmds/set_autoSkills.pike",
		"/lowlib/wapmud2/cmds/disable_autoSkills.pike",
		"/gamelib/cmds/cleanup_non_equipment.pike",
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
			daemon->query_auto_destroy_non_equipment_enabled(player) == 0 &&
			player->query_autofight() == "disable";
			valid = valid &&
				player["/plus/autofight_config_version"] == 7 &&
				player["/plus/autofight_skill_mode"] == "smart" &&
				daemon->query_auto_skill_mode(player) == "smart" &&
				player["/plus/autofight_store_non_equipment"] == 0 &&
			player["/plus/autofight_cleanup_herb"] == 1 &&
			player["/plus/autofight_cleanup_mine"] == 1 &&
			player["/plus/autofight_cleanup_misc"] == 0 &&
			player["/plus/autofight_cleanup_keep"] == 100 &&
			player["/plus/autofight_cleanup_trigger"] == 70 &&
			daemon->query_auto_store_non_equipment_enabled(player) == 0;
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

void test_smart_auto_skill_selection()
{
	test_start("智能推荐、手动指定与关闭自动技能");
	object player = create_runtime_player(
		"__testunit_autofight_skill_selection__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object lingji_skill = (object)(ROOT+
		"/gamelib/single/skills/lingji");
	object lingbailei_skill = (object)(ROOT+
		"/gamelib/single/skills/lingbailei");
	object lingzhi_skill = (object)(ROOT+
		"/gamelib/single/skills/lingzhi");
	string recommended;
	string ensured;
	string mode;
	string error_desc = "";
	int off_result = 0;
	int manual_result = 0;
	int invalid_result = 0;
	int valid = 0;
	mixed err = catch {
		player->level = 40;
		player->set_att_by_level();
		player->skills["lingji"] = ({1,0});
		player->skills["lingbailei"] = ({1,0});
		player->skills["lingzhi"] = ({5,0});
		player->skills_enable = "";
		daemon->initialize_player(player);
		recommended = daemon->query_recommended_auto_skill(player);
		ensured = daemon->ensure_auto_skill(player);
		valid = recommended == "lingbailei" &&
			ensured == "lingbailei" &&
			player->skills_enable == "lingbailei";
		off_result = daemon->set_auto_skill_mode(player,"off");
		valid = valid && off_result &&
			daemon->query_auto_skill_mode(player) == "off" &&
			player->skills_enable == "" &&
			daemon->ensure_auto_skill(player) == "";
		manual_result = daemon->set_selected_auto_skill(player,"lingzhi");
		invalid_result = daemon->set_selected_auto_skill(
			player,"__invalid__");
		mode = daemon->query_auto_skill_mode(player);
		valid = valid && manual_result &&
			mode == "manual" &&
			player->skills_enable == "lingzhi" &&
			!invalid_result;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail(sprintf(
			"自动技能选择错误: recommended=%s ensured=%s current=%s "
			"mode=%s off=%d manual=%d invalid=%d %s",
			recommended,ensured,player->skills_enable,mode,off_result,
			manual_result,invalid_result,error_desc));
	destroy_runtime_player(player);
}

void test_zhenyue_context_skill_selection()
{
	test_start("镇岳助手仅在有效白金PVE按失仇恨、缺护盾顺序施放");
	object tank = clone(GAMELIB_USER);
	object teammate = create_runtime_player(
		"__testunit_autofight_zhenyue_member__");
	object enemy = clone(ROOT+
		"/gamelib/clone/npc/mihuandao/9youdangelang");
	object pvp_enemy = create_runtime_player(
		"__testunit_autofight_zhenyue_pvp_enemy__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero weapon = 0;
	string taunt = "";
	string guard = "";
	string attack = "";
	string direct_context = "";
	string free_context = "";
	string pvp_context = "";
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		tank->set_name("__testunit_autofight_zhenyue_tank__");
		tank->name_cn = "镇岳挂机测试";
		tank->set_project("gamelib");
		tank->setup("testunit-only");
		tank->set_raceId("third");
		tank->set_profeId("zhenyue");
		tank->setup_player("third","zhenyue");
		tank->level = 80;
		tank->set_att_by_level();
		tank->set_mofa(tank->query_mofa_max());
		tank->skills["yueji"] = ({5,0});
		tank->skills["dizhenhou"] = ({4,0});
		tank->skills["shanhebi"] = ({4,0});
		weapon = clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		weapon->move(tank);
		tank->wear(weapon);
		tank->move(room);
		teammate->move(room);
		enemy->move(room);
		tank->set_term("__testunit_autofight_zhenyue_team__");
		teammate->set_term("__testunit_autofight_zhenyue_team__");
		daemon->initialize_player(tank);
		tank->_fight(enemy);
		enemy->force_target(teammate,1000);
		free_context = daemon->query_ready_zhenyue_context_skill(tank);
		set_active_vip(tank,3);
		PROFESSIONVIPD->initialize_player(tank);
		PROFESSIONVIPD->set_auto_enabled(tank,1);
		PROFESSIONVIPD->set_strategy(tank,"team");
		direct_context = daemon->query_ready_zhenyue_context_skill(tank);
		taunt = daemon->query_ready_auto_skill(tank);
		enemy->force_target(tank,1000);
		guard = daemon->query_ready_auto_skill(tank);
		tank->apply_team_guard(500,12);
		attack = daemon->query_ready_auto_skill(tank);
		tank->_clean_fight();
		tank->_fight(pvp_enemy);
		pvp_context = daemon->query_ready_zhenyue_context_skill(tank);
		valid = free_context == "" && direct_context == "dizhenhou" &&
			taunt == "dizhenhou" && guard == "shanhebi" &&
			attack == "yueji" && pvp_context == "";
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail(sprintf(
			"免费=%s 嘲讽=%s 直接=%s 护盾=%s 攻击=%s PVP=%s 战斗=%d 敌人=%d 模式=%s "
			"法力=%d/%d 公冷=%d 技能冷却=%d/%d/%d %s",
			free_context,taunt,direct_context,guard,attack,pvp_context,
			tank->query_in_combat(),
			tank->query_enemy()==enemy,daemon->query_auto_skill_mode(tank),
			tank->get_cur_mofa(),tank->query_mofa_max(),tank->timeCold,
			(int)tank->f_skills["dizhenhou"],
			(int)tank->f_skills["shanhebi"],
			(int)tank->f_skills["yueji"],
			daemon->query_auto_skill_unready_reason(tank,"dizhenhou")+"/"+
			daemon->query_auto_skill_unready_reason(tank,"shanhebi")+"/"+
			daemon->query_auto_skill_unready_reason(tank,"yueji")+" "+
			error_desc));
	if(tank)
		tank->_clean_fight();
	destroy_runtime_player(tank);
	destroy_runtime_player(teammate);
	destroy_runtime_player(enemy);
	destroy_runtime_player(pvp_enemy);
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
		set_active_vip(normal_player,1);
		valid = daemon->query_daily_seconds_for(normal_player) == 10*60*60 &&
			daemon->query_time_left(normal_player) == 9*60*60;
		set_active_vip(normal_player,4);
		valid = valid &&
			daemon->query_daily_seconds_for(normal_player) == 16*60*60 &&
			daemon->query_time_left(normal_player) == 15*60*60;
		set_active_vip(normal_player,0);
		valid = valid &&
			daemon->query_daily_seconds_for(normal_player) == 8*60*60 &&
			daemon->query_time_left(normal_player) == 7*60*60;

		set_active_vip(vip_player,4);
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

void test_vip_quota_exhausted_guidance()
{
	test_start("挂机额度用完按VIP档位提示升级或最高额度");
	object normal_player = create_runtime_player(
		"__testunit_autofight_quota_normal__");
	object vip4_player = create_runtime_player(
		"__testunit_autofight_quota_vip4__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	string command_source = Stdio.read_file(
		ROOT+"/gamelib/cmds/autofight.pike");
	string api_source = Stdio.read_file(
		ROOT+"/gamelib/single/daemons/http_api_daemon.pike");
	string vue_source = Stdio.read_file(ROOT+"/vue_source/js/app.js");
	string normal_message = "";
	string vip4_message = "";
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		daemon->initialize_player(normal_player);
		normal_player["/plus/autofight_time_left"] = 0;
		normal_message = daemon->query_quota_exhausted_message(
			normal_player);
		set_active_vip(vip4_player,4);
		daemon->initialize_player(vip4_player);
		vip4_player["/plus/autofight_time_left"] = 0;
		vip4_message = daemon->query_quota_exhausted_message(vip4_player);
		valid = daemon->can_upgrade_daily_time(normal_player) == 1 &&
			daemon->can_upgrade_daily_time(vip4_player) == 0 &&
			daemon->is_quota_exhausted_reason(
				normal_player,normal_message) == 1 &&
			daemon->is_quota_exhausted_reason(
				normal_player,"死亡或灵魂状态不能开启自动挂机") == 0 &&
			search(normal_message,"今天的8小时") != -1 &&
			search(normal_message,"VIP1（水晶会员）") != -1 &&
			search(normal_message,"10小时") != -1 &&
			search(vip4_message,"今天的16小时") != -1 &&
			search(vip4_message,"VIP4（钻石会员）") != -1 &&
			search(vip4_message,"最高额度") != -1 &&
			search(vip4_message,"升级至") == -1 &&
			command_source &&
			search(command_source,"[提高VIP等级:vip_service_list]") != -1 &&
			search(command_source,"[玉石不足可捐款:add_szx_fee]") != -1 &&
			api_source && search(api_source,"quota_exhausted") != -1 &&
			search(api_source,"can_upgrade_vip") != -1 &&
			vue_source && search(vue_source,"data.quota_exhausted") != -1 &&
			search(vue_source,"runUiToastAction") != -1;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("挂机额度提示分级错误: "+normal_message+" / "+
			vip4_message+" "+error_desc);
	destroy_runtime_player(normal_player);
	destroy_runtime_player(vip4_player);
}

void test_vip_labels_and_plan()
{
	test_start("挂机VIP等级名称与统一权益入口");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	string command_source = Stdio.read_file(
		ROOT+"/gamelib/cmds/autofight.pike");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		valid = daemon->query_vip_label(0) == "普通玩家" &&
			daemon->query_vip_label(1) == "VIP1（水晶会员）" &&
			daemon->query_vip_label(2) == "VIP2（黄金会员）" &&
			daemon->query_vip_label(3) == "VIP3（白金会员）" &&
			daemon->query_vip_label(4) == "VIP4（钻石会员）" &&
			command_source &&
			search(command_source,"自动挂机·VIP权益总览") != -1 &&
			search(command_source,"查看VIP挂机分级") != -1 &&
			search(command_source,
				"核心挂机免费，VIP提升时长和清包效率") != -1;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("VIP名称或统一权益总览错误: "+error_desc);
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
		set_active_vip(player,1);
		player["/plus/autofight_auto_sell_mode"] = "normal";
		valid = daemon->query_auto_sell_enabled(player) == 1 &&
			daemon->query_auto_sell_trigger_percent(player) == 100 &&
			daemon->query_auto_sell_batch_size(player) == 1 &&
			daemon->query_auto_sell_mode_requirement("excellent") == 2;

		set_active_vip(player,2);
		player["/plus/autofight_auto_sell_mode"] = "excellent";
		player["/plus/autofight_sell_level_gap"] = 3;
		valid = valid &&
			daemon->query_auto_sell_enabled(player) == 1 &&
			daemon->query_auto_sell_trigger_percent(player) == 90 &&
			daemon->query_auto_sell_batch_size(player) == 2;

		set_active_vip(player,3);
		player["/plus/autofight_auto_sell_mode"] = "refined";
		player["/plus/autofight_sell_level_gap"] = 0;
		valid = valid &&
			daemon->query_auto_sell_enabled(player) == 1 &&
			daemon->query_auto_sell_trigger_percent(player) == 80 &&
			daemon->query_auto_sell_batch_size(player) == 4;

		set_active_vip(player,4);
		valid = valid &&
			daemon->query_auto_sell_trigger_percent(player) == 70 &&
			daemon->query_auto_sell_batch_size(player) == 8;

		set_active_vip(player,1);
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
		set_active_vip(player,4);
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
		set_active_vip(player,4);
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
	test_start("挂机按熟练度采集、拒绝拾取原矿并自动出售原料");
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

		// 锌矿需要15级熟练度。挂机既不能采，也不能把矿脉当掉落捡走。
		object locked_ore = clone(ROOT+
			"/gamelib/clone/item/material/xinkuang");
		locked_ore->move(room);
		valid = valid && daemon->query_gather_source(player) == 0 &&
			daemon->query_loot_item(player) == 0;
		destruct(locked_ore);

		// 甘草同样需要15级熟练度，草药模式也不能绕过门槛拾取药株。
		player["/plus/autofight_gather_mode"] = "herb";
		object locked_herb = clone(ROOT+
			"/gamelib/clone/item/material/cy_gancao");
		locked_herb->move(room);
		valid = valid && daemon->query_gather_source(player) == 0 &&
			daemon->query_loot_item(player) == 0;
		destruct(locked_herb);

		object herb = clone(ROOT+
			"/gamelib/clone/item/material/cy_muhudie");
		herb->move(room);
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
		test_fail("采集门槛、原矿拾取、9999堆叠或原料出售错误: "+error_desc);
	if(room){
		foreach(all_inventory(room),object item)
			if(item != player)
				destruct(item);
		destruct(room);
	}
	destroy_runtime_player(player);
}

void test_non_equipment_destroy_safety()
{
	test_start("一键销毁只清除普通非装备并按堆叠数量预览");
	object player = create_runtime_player(
		"__testunit_non_equipment_destroy__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object cleanup_command = (object)(ROOT+
		"/gamelib/cmds/cleanup_non_equipment.pike");
	object material = clone(ROOT+
		"/gamelib/clone/item/material/tongkuangshi");
	object task_material = clone(ROOT+
		"/gamelib/clone/item/material/cf_suibu");
	object restricted_material = clone(ROOT+
		"/gamelib/clone/item/material/cf_suibu");
	object vip_material = clone(ROOT+
		"/gamelib/clone/item/material/cf_suibu");
	object weapon = clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	object book = clone(ROOT+
		"/gamelib/clone/item/book/lingren");
	object food = clone(ROOT+
		"/gamelib/clone/item/food/ganliang");
	object|zero original_player = this_player();
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		daemon->initialize_player(player);
		material->amount = 37;
		material->move(player);
		task_material->set_item_task(1);
		task_material->move(player);
		restricted_material->set_item_canDrop(0);
		restricted_material->move(player);
		vip_material->set_toVip(1);
		vip_material->move(player);
		weapon->move(player);
		book->move(player);
		food->move(player);
		mapping preview =
			daemon->query_non_equipment_destroy_preview(player);
		valid = preview["object_count"] == 1 &&
			preview["item_count"] == 37 &&
			environment(material) == player &&
			daemon->query_non_equipment_destroy_reject_reason(
				player,weapon) == "equipment" &&
			daemon->query_non_equipment_destroy_reject_reason(
				player,book) == "protected_type" &&
			daemon->query_non_equipment_destroy_reject_reason(
				player,food) == "protected_type" &&
			daemon->query_non_equipment_destroy_reject_reason(
				player,task_material) == "task_item" &&
			daemon->query_non_equipment_destroy_reject_reason(
				player,restricted_material) == "not_droppable" &&
			daemon->query_non_equipment_destroy_reject_reason(
				player,vip_material) == "vip_item";
		set_this_player(player);
		cleanup_command->main(0);
		valid = valid && environment(material) == player;
		cleanup_command->main("confirm");
		valid = valid &&
			!present("tongkuangshi",player) &&
			environment(task_material) == player &&
			environment(restricted_material) == player &&
			environment(vip_material) == player &&
			environment(weapon) == player &&
			environment(book) == player &&
			environment(food) == player &&
			sizeof(all_inventory(player)) == 6;
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
		test_fail("销毁预览、堆叠计数或保护规则错误: "+error_desc);
	destroy_runtime_player(player);
}

void test_vip_non_equipment_cleanup_tiers()
{
	test_start("VIP自动存仓与销毁按等级递进解锁");
	object player = create_runtime_player(
		"__testunit_autofight_cleanup_tiers__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object material = clone(ROOT+
		"/gamelib/clone/item/material/tongkuangshi");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		daemon->initialize_player(player);
		player["/plus/autofight_store_non_equipment"] = 1;
		player["/plus/autofight_destroy_non_equipment"] = 1;
		material->amount = 150;
		material->move(player);
		valid = !daemon->query_auto_store_non_equipment_enabled(player) &&
			!daemon->query_auto_destroy_non_equipment_enabled(player) &&
			daemon->query_auto_cleanup_trigger_percent(player) == 100;

		set_active_vip(player,1);
		valid = valid &&
			daemon->query_auto_store_non_equipment_enabled(player) &&
			daemon->query_auto_destroy_non_equipment_enabled(player) &&
			daemon->query_auto_cleanup_trigger_percent(player) == 90 &&
			daemon->query_auto_store_batch_size(player) == 1 &&
			daemon->query_auto_cleanup_category_enabled(player,"herb") &&
			daemon->query_auto_cleanup_category_enabled(player,"mine") &&
			!daemon->query_auto_cleanup_category_enabled(player,"misc");

		set_active_vip(player,2);
		player["/plus/autofight_cleanup_herb"] = 0;
		player["/plus/autofight_cleanup_mine"] = 1;
		player["/plus/autofight_cleanup_misc"] = 1;
		valid = valid &&
			daemon->query_auto_cleanup_trigger_percent(player) == 85 &&
			daemon->query_auto_store_batch_size(player) == 2 &&
			!daemon->query_auto_cleanup_category_enabled(player,"herb") &&
			daemon->query_auto_cleanup_category_enabled(player,"mine") &&
			daemon->query_auto_cleanup_category_enabled(player,"misc");

		set_active_vip(player,3);
		player["/plus/autofight_cleanup_keep"] = 100;
		valid = valid &&
			daemon->query_auto_cleanup_trigger_percent(player) == 80 &&
			daemon->query_auto_store_batch_size(player) == 4 &&
			daemon->query_auto_cleanup_process_amount(player,material) == 50;

		set_active_vip(player,4);
		player["/plus/autofight_cleanup_trigger"] = 90;
		valid = valid &&
			daemon->query_auto_cleanup_trigger_percent(player) == 90 &&
			daemon->query_auto_store_batch_size(player) == 8 &&
			daemon->set_auto_cleanup_name_mode(
				player,material->query_name(),"protect") &&
			daemon->query_auto_cleanup_reject_reason(player,material) ==
				"protected_list" &&
			daemon->set_auto_cleanup_name_mode(
				player,material->query_name(),"force") &&
			daemon->query_auto_cleanup_reject_reason(player,material) == "";

		set_active_vip(player,0);
		valid = valid &&
			!daemon->query_auto_store_non_equipment_enabled(player) &&
			!daemon->query_auto_destroy_non_equipment_enabled(player);
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("VIP非装备清理分级、保留量或名单规则错误: "+error_desc);
	destroy_runtime_player(player);
}

void test_end_to_end_auto_destroy_non_equipment()
{
	test_start("挂机脱战自动销毁非装备并保留装备和补给");
	object player = create_runtime_player(
		"__testunit_autofight_destroy_e2e__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+"/gamelib/d/jinaodao/huangshayuanye");
	object flush_command = (object)(ROOT+
		"/lowlib/wapmud2/cmds/flushview.pike");
	object material = clone(ROOT+
		"/gamelib/clone/item/material/tongkuangshi");
	object weapon = clone(ROOT+
		"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	object food = clone(ROOT+
		"/gamelib/clone/item/food/ganliang");
	object|zero original_player = this_player();
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		player->move(room);
		set_active_vip(player,1);
		material->amount = 25;
		material->move(player);
		weapon->move(player);
		food->move(player);
		set_this_player(player);
		daemon->initialize_player(player);
		player["/plus/autofight_destroy_non_equipment"] = 1;
		player["/plus/autofight_smart_route"] = 0;
		while(daemon->query_backpack_percent(player) < 90){
			object protected_food = clone(ROOT+
				"/gamelib/clone/item/food/ganliang");
			protected_food->move(player);
		}
		valid = daemon->query_auto_destroy_non_equipment_enabled(player) == 1 &&
			daemon->should_auto_destroy_non_equipment(player) == 1;
		daemon->start_autofight(player);
		flush_command->main(0);
		valid = valid && !present("tongkuangshi",player) &&
			environment(weapon) == player &&
			environment(food) == player &&
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
		test_fail("挂机自动销毁链路或保护规则错误: "+error_desc);
	if(room){
		foreach(all_inventory(room),object item)
			if(item != player)
				destruct(item);
		destruct(room);
	}
	destroy_runtime_player(player);
}

void test_end_to_end_auto_storage_priority()
{
	test_start("挂机优先存仓、按VIP3保留材料且满仓转销毁");
	object player = create_runtime_player(
		"__testunit_autofight_storage_e2e__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+"/gamelib/d/jinaodao/huangshayuanye");
	object flush_command = (object)(ROOT+
		"/lowlib/wapmud2/cmds/flushview.pike");
	object material = clone(ROOT+
		"/gamelib/clone/item/material/tongkuangshi");
	object|zero original_player = this_player();
	string error_desc = "";
	int valid = 0;
	int storage_blocked = 0;
	int destroy_ready = 0;
	int material_removed = 0;
	int still_running = 0;
	int initial_store_ready = 0;
	int initial_destroy_ready = 0;
	int partial_retained = 0;
	int packaged_ok = 0;
	mixed err = catch {
		player->move(room);
		set_active_vip(player,3);
		player->packageLevel = 20;
		player->packaged_items = ({});
		material->amount = 250;
		material->move(player);
		set_this_player(player);
		daemon->initialize_player(player);
		player["/plus/autofight_store_non_equipment"] = 1;
		player["/plus/autofight_destroy_non_equipment"] = 1;
		player["/plus/autofight_cleanup_keep"] = 100;
		player["/plus/autofight_smart_route"] = 0;
		while(daemon->query_backpack_percent(player) < 80){
			object protected_food = clone(ROOT+
				"/gamelib/clone/item/food/ganliang");
			protected_food->move(player);
		}
		initial_store_ready =
			daemon->should_auto_store_non_equipment(player);
		initial_destroy_ready =
			daemon->should_auto_destroy_non_equipment(player);
		valid = initial_store_ready && initial_destroy_ready;
		daemon->start_autofight(player);
		flush_command->main(0);
		partial_retained = environment(material) == player &&
			material->amount == 100;
		packaged_ok =
			sizeof(player->packaged_items) == 1 &&
			player->packaged_items[0][0] == "tongkuangshi" &&
			player->packaged_items[0][6] == 150;
		valid = valid && partial_retained && packaged_ok &&
			player->query_autofight() == "enable" &&
			!player->in_combat;
		while(sizeof(player->packaged_items) < player->query_cangku_size())
			player->packaged_items += ({({
				"testdummy","测试占位","测试占位",
				"material/cf_suibu",0,0,1,
			})});
		player["/plus/autofight_cleanup_keep"] = 0;
		while(daemon->query_backpack_percent(player) < 80){
			object fallback_food = clone(ROOT+
				"/gamelib/clone/item/food/ganliang");
			fallback_food->move(player);
		}
		storage_blocked =
			!daemon->should_auto_store_non_equipment(player);
		destroy_ready =
			daemon->should_auto_destroy_non_equipment(player);
		valid = valid && storage_blocked && destroy_ready;
		flush_command->main(0);
		material_removed = !present("tongkuangshi",player);
		still_running = player->query_autofight() == "enable";
		valid = valid && material_removed && still_running;
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
			"自动存仓优先级、仓库记录或材料保留量错误: initial_store=%d initial_destroy=%d retained=%d packaged=%d blocked=%d ready=%d removed=%d running=%d %s",
			initial_store_ready,initial_destroy_ready,partial_retained,
			packaged_ok,storage_blocked,destroy_ready,material_removed,still_running,
			error_desc));
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
		(["level":20,"race":"third",
			"path":"shierxianjing/taoyuantongshijiuceng",
			"target":20]),
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
			"path":"plxianjing/dangyunshijie","target":54]),
		(["level":57,"race":"monst",
			"path":"plxianjing/binghuanyuntai","target":57]),
		(["level":61,"race":"third",
			"path":"penglaihuanjing/yunyepingyuan",
			"target":61]),
		(["level":63,"race":"human",
			"path":"penglaihuanjing/qiushuangshilu",
			"target":63]),
		(["level":65,"race":"monst",
			"path":"penglaihuanjing/liehuochitang",
			"target":65]),
		(["level":67,"race":"third",
			"path":"klshuanjingwaicheng/heiheyuan",
			"target":67]),
		(["level":69,"race":"human",
			"path":"klshuanjingwaicheng/heishandong",
			"target":69]),
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

void test_level_seventeen_dynamic_room_recovery()
{
	test_start("17级共享房间被高阶动态化后恢复原怪并继续攻击");
	object player = create_runtime_player(
		"__testunit_autofight_level17_a__");
	object second_player = create_runtime_player(
		"__testunit_autofight_level17_b__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+
		"/gamelib/d/shierxianjing/taoyuantongjiuceng");
	object|zero npc = 0;
	object|zero target = 0;
	string error_desc = "";
	int valid = 0;
	int restored_count = 0;
	mixed err = catch {
		foreach(all_inventory(room),object old_item)
			destruct(old_item);
		player->level = 17;
		player->set_att_by_level();
		second_player->level = 17;
		second_player->set_att_by_level();
		player->move(room);
		second_player->move(room);
		npc = clone(ROOT+
			"/gamelib/clone/npc/shierxianshan/qingyunshou17");
		npc->_npcLevel = 70;
		npc->_boss = 1;
		npc->_meritocrat = 1;
		npc->setup_npc_dongtai(player);
		npc->move(room);
		daemon->initialize_player(player);
		player["/plus/autofight_smart_route"] = 1;
		restored_count = MUD_ROOMD->restore_low_level_room_npcs(player);
		target = daemon->query_target(player);
		valid = target && target->query_level() == 17 &&
			npc->query_level() == 17 &&
			npc->_boss == 0 && npc->_meritocrat == 0;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else{
		if(npc)
			error_desc += " restored="+restored_count+
				" npc_level="+npc->query_level()+
				" boss="+npc->_boss+
				" task="+npc->_tasknpc+
				" elite="+npc->_meritocrat+
				" combat="+npc->in_combat+
				" char="+npc->is("character")+
				" npc="+npc->is("npc")+
				" hind="+npc->hind+
				" life="+npc->get_cur_life()+
				" npc_type="+npc->query_npc_type()+
				" me_race="+player->query_raceId()+
				" npc_race="+npc->query_raceId()+
				" summon_fn="+functionp(npc->query_summon_type)+
				" target="+(target ? target->query_name() : "0")+
				" target_level="+(target ? target->query_level() : 0)+
				" target_same="+(target==npc);
		test_fail("17级动态怪污染恢复失败: "+error_desc);
	}
	if(room){
		foreach(all_inventory(room),object item)
			if(item != player && item != second_player)
				destruct(item);
		destruct(room);
	}
	destroy_runtime_player(player);
	destroy_runtime_player(second_player);
}

void test_real_route_targets()
{
	test_start("50至69级逐级有同级怪且70级动态区可攻击");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object|zero original_player = this_player();
	string error_desc = "";
	int valid = 1;
	for(int route_level=50;route_level<=70;route_level++){
		object player = create_runtime_player(sprintf(
			"__testunit_autofight_route_%d__",route_level));
		object|zero room;
		mixed err = catch {
			player->level = route_level;
			player->set_att_by_level();
			player->set_raceId("third");
			set_this_player(player);
			mapping route = daemon->query_training_route(player);
			room = clone(ROOT+"/gamelib/d/"+(string)route["path"]);
			player->move(room);
			daemon->initialize_player(player);
			player["/plus/autofight_smart_route"] = 1;
			object target = daemon->query_target(player);
			valid = valid && target &&
				target->query_level() == route_level &&
				(int)route["level"] == route_level;
		};
		if(err){
			valid = 0;
			error_desc += sprintf("%d: %s",
				route_level,describe_error(err));
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

void test_level_twenty_fangshi_route_recovery()
{
	test_start("20级方士从可见25级怪错误地图换区后自动开战");
	object player = create_runtime_player(
		"__testunit_autofight_route_recovery_20__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+
		"/gamelib/d/liangjinghu/yanghuxuanqiao");
	object flush_command = (object)(ROOT+
		"/lowlib/wapmud2/cmds/flushview.pike");
	object|zero original_player = this_player();
	mapping(string:int) level_window = ([]);
	string first_path = "";
	string error_desc = "";
	int visible_monsters = 0;
	int wrong_target_blocked = 0;
	int valid = 0;
	mixed err = catch {
		player->level = 20;
		player->set_att_by_level();
		player->move(room);
		set_this_player(player);
		daemon->initialize_player(player);
		player["/plus/autofight_smart_route"] = 1;
		player["/plus/autofight_roam"] = 0;
		level_window = daemon->query_target_level_window(player);
		visible_monsters = daemon->query_visible_monster_count(player);
		wrong_target_blocked = daemon->query_target(player) == 0;
		daemon->start_autofight(player);
		flush_command->main(0);
		first_path = daemon->query_current_room_path(player);
		// 实际公共房间可能遗留可拾取物；挂机会先拾取再继续寻怪。
		for(int recovery_tick = 0;
		   recovery_tick < 10 && !player->in_combat;recovery_tick++)
			flush_command->main(0);
		valid = visible_monsters >= 6 && wrong_target_blocked &&
			level_window["minimum"] == 16 &&
			level_window["maximum"] == 20 &&
			first_path == "shierxianjing/taoyuantongshijiuceng" &&
			player->in_combat && player->query_enemy() &&
			player->query_enemy()->query_level() == 20;
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
			"等级过滤或换区恢复错误: visible=%d blocked=%d range=%O path=%s %s",
			visible_monsters,wrong_target_blocked,level_window,
			first_path,error_desc));
	if(room){
		foreach(all_inventory(room),object item)
			if(item != player)
				destruct(item);
		destruct(room);
	}
	destroy_runtime_player(player);
}

void test_same_area_unsafe_monster_recovery()
{
	test_start("同区域可见怪全部超限时直达推荐层并恢复战斗");
	object player = create_runtime_player(
		"__testunit_autofight_same_area_recovery__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+
		"/gamelib/d/shierxianjing/taoyuantongshijiuceng");
	object flush_command = (object)(ROOT+
		"/lowlib/wapmud2/cmds/flushview.pike");
	object|zero original_player = this_player();
	string first_path = "";
	string error_desc = "";
	int visible_monsters = 0;
	int unsafe_targets_blocked = 0;
	int route_requested = 0;
	int valid = 0;
	mixed err = catch {
		player->level = 17;
		player->set_att_by_level();
		player->move(room);
		set_this_player(player);
		daemon->initialize_player(player);
		player["/plus/autofight_smart_route"] = 1;
		player["/plus/autofight_roam"] = 0;
		visible_monsters = daemon->query_visible_monster_count(player);
		unsafe_targets_blocked = daemon->query_target(player) == 0;
		daemon->record_no_target(player);
		route_requested =
			daemon->should_route_to_training_area(player) == 1;
		daemon->clear_no_target(player);
		daemon->start_autofight(player);
		flush_command->main(0);
		first_path = daemon->query_current_room_path(player);
		flush_command->main(0);
		valid = visible_monsters == 4 && unsafe_targets_blocked &&
			route_requested &&
			first_path == "shierxianjing/taoyuantongjiuceng" &&
			player->in_combat && player->query_enemy() &&
			player->query_enemy()->query_level() == 17;
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
			"同区域纠偏失败: visible=%d blocked=%d route=%d path=%s combat=%d %s",
			visible_monsters,unsafe_targets_blocked,route_requested,
			first_path,player ? player->in_combat : 0,error_desc));
	if(room){
		foreach(all_inventory(room),object item)
			if(item != player)
				destruct(item);
		destruct(room);
	}
	destroy_runtime_player(player);
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

void test_end_to_end_auto_skill_perform()
{
	test_start("挂机战斗中按冷却自动施放已选技能");
	object player = create_runtime_player(
		"__testunit_autofight_skill_perform__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+
		"/gamelib/d/jinaodao/huangshayuanye");
	object flush_command = (object)(ROOT+
		"/lowlib/wapmud2/cmds/flushview.pike");
	object lingji_skill = (object)(ROOT+
		"/gamelib/single/skills/lingji");
	object enemy = clone(ROOT+
		"/gamelib/clone/npc/jinaodao/shachong1");
	object|zero weapon;
	object|zero original_player = this_player();
	string error_desc = "";
	string ready_skill = "";
	int before_mofa = 0;
	int after_mofa = 0;
	int cold = 0;
	int entered_combat = 0;
	int weapon_ready = 0;
	int life_recovery = 0;
	int mana_recovery = 0;
	int resting = 0;
	int resonance = 0;
	int active_player = 0;
	string block_reason = "";
	int valid = 0;
	mixed err = catch {
		player->move(room);
		enemy->move(room);
		// 背包满阻断已有独立用例；自动施法场景只保留测试武器。
		foreach(all_inventory(player),object item)
			destruct(item);
		weapon = clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		weapon->move(player);
		player->wear(weapon);
		weapon_ready = weapon->equiped;
		player->skills["lingji"] = ({1,0});
		player->set_life(player->query_life_max());
		player->set_mofa(player->query_mofa_max());
		set_this_player(player);
		daemon->initialize_player(player);
		player["/plus/autofight_smart_route"] = 0;
		daemon->set_selected_auto_skill(player,"lingji");
		daemon->start_autofight(player);
		// 自动寻敌已有独立端到端用例；这里固定目标，避免房间刷新时序
		// 让“自动施法”测试随机退化成第二次寻敌测试。
		player->kill(enemy,0);
		entered_combat = player->in_combat;
		before_mofa = player->get_cur_mofa();
		player->timeCold = 0;
		player->f_skills["lingji"] = 0;
		ready_skill = daemon->query_ready_auto_skill(player);
		set_this_player(player);
		life_recovery = daemon->should_recover_life(player);
		mana_recovery = daemon->should_recover_mana(player);
		resting = daemon->query_is_resting(player);
		resonance = PROFESSIONVIPD->query_resonance_enabled(player);
		block_reason = daemon->query_runtime_block_reason(player);
		active_player = this_player()==player;
		flush_command->main(0);
		after_mofa = player->get_cur_mofa();
		cold = (int)player->f_skills["lingji"];
		valid = player->query_autofight() == "enable" &&
			entered_combat && weapon_ready && ready_skill == "lingji" &&
			cold > 1 && after_mofa < before_mofa;
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
			"挂机自动施放技能错误: combat=%d weapon=%d ready=%s "
			"mofa=%d/%d cold=%d life_recover=%d mana_recover=%d "
			"rest=%d resonance=%d active=%d block=%s %s",
			entered_combat,weapon_ready,ready_skill,before_mofa,after_mofa,
			cold,life_recovery,mana_recovery,resting,resonance,
			active_player,block_reason,error_desc));
	if(room){
		foreach(all_inventory(room),object item)
			if(item != player)
				destruct(item);
		destruct(room);
	}
	destroy_runtime_player(player);
}

void test_end_to_end_empty_room_switch()
{
	test_start("智能寻路空图防抖后自动换图并恢复攻击");
	object player = create_runtime_player(
		"__testunit_autofight_empty_switch__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+"/gamelib/d/mihuandao/nongwusenlin");
	object flush_command = (object)(ROOT+
		"/lowlib/wapmud2/cmds/flushview.pike");
	object|zero target;
	object|zero enemy;
	object|zero switched_room;
	object|zero original_player = this_player();
	string error_desc = "";
	string current_path = "";
	string available_exit = "";
	int waited_before_switch = 0;
	int ticks_after_two = 0;
	int ticks_after_three = 0;
	int switched = 0;
	int stayed_in_training_area = 0;
	int started_combat = 0;
	int matched_enemy = 0;
	int valid = 0;
	mixed err = catch {
		room->hidden_exits["south"] = 1;
		room->hidden_exits["west"] = 1;
		room->hidden_exits["north"] = 1;
		player->move(room);
		// 进入房间会触发一次正常刷新，进入后再清空才能模拟真实空图。
		foreach(all_inventory(room),object old_item)
			if(old_item != player)
				destruct(old_item);
		set_this_player(player);
		daemon->initialize_player(player);
		player["/plus/autofight_smart_route"] = 1;
		player["/plus/autofight_roam"] = 0;
		daemon->start_autofight(player);
		for(int i = 0;i < 2;i++)
			flush_command->main(0);
		ticks_after_two =
			(int)player["/tmp/autofight_no_target_ticks"];
		waited_before_switch = environment(player) == room &&
			!player->in_combat &&
			daemon->query_safe_exit(player) == "";
		flush_command->main(0);
		ticks_after_three =
			(int)player["/tmp/autofight_no_target_ticks"];
		available_exit = daemon->query_safe_exit(player);
		switched_room = environment(player);
		current_path = daemon->query_current_room_path(player);
		switched = switched_room && switched_room != room &&
			current_path == "mihuandao/lvyinshanqiu";
		player["/tmp/autofight_last_route_time"] = time()-20;
		stayed_in_training_area =
			daemon->should_route_to_training_area(player) == 0;
		target = clone(ROOT+
			"/gamelib/clone/npc/mihuandao/10xiongmengeyu");
		target->move(switched_room);
		for(int resume_tick = 0;resume_tick < 3 &&
		    !player->in_combat;resume_tick++)
			flush_command->main(0);
		started_combat = player->in_combat;
		enemy = player->query_enemy();
		matched_enemy = enemy && enemy->is("npc") &&
			environment(enemy) == switched_room;
		valid = waited_before_switch && switched &&
			stayed_in_training_area && started_combat && matched_enemy;
		daemon->stop_autofight(player);
		player->_clean_fight();
		if(enemy)
			enemy->_clean_fight();
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
			"空图换图或恢复攻击错误: wait=%d ticks=%d/%d "
			"exit=%s switched=%d stable=%d combat=%d enemy=%d "
			"room=%s smart=%d roam=%d leave=%d %s",
			waited_before_switch,ticks_after_two,ticks_after_three,
			available_exit,switched,stayed_in_training_area,
			started_combat,matched_enemy,current_path,
			daemon->query_smart_route_enabled(player),
			daemon->query_roam_enabled(player),
			daemon->can_auto_leave_current_room(player),error_desc));
	if(target){
		target->_clean_fight();
		destruct(target);
	}
	if(room){
		foreach(all_inventory(room),object item)
			if(item != player)
				destruct(item);
		destruct(room);
	}
	destroy_runtime_player(player);
}

void test_roam_wait_and_backtrack_guard()
{
	test_start("区域巡游禁止立即折返并可延迟脱离死路");
	object player = create_runtime_player(
		"__testunit_autofight_roam_guard__");
	object daemon = (object)(ROOT+
		"/gamelib/single/daemons/autofightd.pike");
	object room = clone(ROOT+
		"/gamelib/d/liuguangpingyuan/liuguangchalu");
	object|zero original_player = this_player();
	string direction;
	string back_direction;
	string delayed_back_direction;
	string previous_direction;
	string previous_path;
	string error_desc = "";
	object current_room;
	int valid = 0;
	mixed err = catch {
		foreach(all_inventory(room),object old_item)
			destruct(old_item);
		player->level = 50;
		player->set_att_by_level();
		player->move(room);
		set_this_player(player);
		daemon->initialize_player(player);
		player["/plus/autofight_smart_route"] = 0;
		player["/plus/autofight_roam"] = 1;
		daemon->start_autofight(player);
		valid = daemon->query_safe_exit(player) == "";
		daemon->record_no_target(player);
		daemon->record_no_target(player);
		valid = valid && daemon->query_safe_exit(player) == "";
		daemon->record_no_target(player);
		direction = daemon->query_safe_exit(player);
		previous_path = daemon->query_current_room_path(player);
		valid = valid && direction != "";
		if(direction != ""){
			daemon->record_roam(player);
			player->command("leave "+direction);
		}
		valid = valid &&
			daemon->query_current_room_path(player) != previous_path;
		current_room = environment(player);
		previous_direction = "";
		foreach(indices(current_room->exits),string candidate_direction){
			if((string)current_room->exits[candidate_direction] ==
			   ROOT+"/gamelib/d/"+previous_path)
				previous_direction = candidate_direction;
			else
				current_room->hidden_exits[candidate_direction] = 1;
		}
		daemon->record_no_target(player);
		daemon->record_no_target(player);
		daemon->record_no_target(player);
		back_direction = daemon->query_safe_exit(player);
		valid = valid && previous_direction != "" && back_direction == "";
		daemon->record_no_target(player);
		daemon->record_no_target(player);
		daemon->record_no_target(player);
		delayed_back_direction = daemon->query_safe_exit(player);
		valid = valid && delayed_back_direction == previous_direction;
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
		test_fail("巡游等待、折返防抖或死路恢复错误: "+error_desc);
	if(room)
		destruct(room);
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
		set_active_vip(player,4);
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
	string autofight_daemon_source = Stdio.read_file(
		ROOT+"/gamelib/single/daemons/autofightd.pike");
	string flush_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/cmds/flushview.pike");
	string set_skill_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/cmds/set_autoSkills.pike");
	string disable_skill_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/cmds/disable_autoSkills.pike");
	string inventory_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/single/viewd.pike");
	if(api_source && renderer_source && vue_source && index_source &&
	   daily_source && kill_source && leave_source && user_source &&
	   autofight_source && autofight_daemon_source && flush_source &&
	   set_skill_source && disable_skill_source && inventory_source &&
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
	   search(autofight_source,"cleanup_non_equipment") != -1 &&
	   search(autofight_source,"自动存仓") != -1 &&
	   search(autofight_source,"智能推荐攻击技能") != -1 &&
	   search(autofight_daemon_source,
		"query_recommended_auto_skill") != -1 &&
	   search(flush_source,"query_ready_auto_skill(me)") != -1 &&
	   search(set_skill_source,"autofight_skill_mode\"] = \"manual\"") != -1 &&
	   search(disable_skill_source,"autofight_skill_mode\"] = \"off\"") != -1 &&
	   search(flush_source,"perform_auto_sell(me)") != -1 &&
	   search(flush_source,"perform_auto_store_non_equipment") != -1 &&
	   search(flush_source,"perform_non_equipment_destroy") != -1 &&
	   search(inventory_source,"一键安全销毁非装备") != -1)
		test_pass();
	else
		test_fail("API、Vue、每日重置或防外挂豁免缺少接线");
}

int main()
{
	werror("\n========== 自动打怪／挂机系统测试 ==========\n");
	test_runtime_compile();
	test_defaults_and_switch();
	test_smart_auto_skill_selection();
	test_zhenyue_context_skill_selection();
	test_vip_daily_limits();
	test_vip_quota_exhausted_guidance();
	test_vip_labels_and_plan();
	test_vip_auto_sell_tiers();
	test_auto_sell_protection_rules();
	test_auto_sell_settlement();
	test_time_and_low_life_guard();
	test_gathering_and_material_cleanup();
	test_non_equipment_destroy_safety();
	test_vip_non_equipment_cleanup_tiers();
	test_end_to_end_auto_destroy_non_equipment();
	test_end_to_end_auto_storage_priority();
	test_recovery_skips_unusable_medicine();
	test_duplicate_object_count();
	test_recovery_selection_checkmarks();
	test_smart_route_selection();
	test_smart_target_level_window();
	test_level_seventeen_dynamic_room_recovery();
	test_real_route_targets();
	test_level_twenty_fangshi_route_recovery();
	test_same_area_unsafe_monster_recovery();
	test_auto_rest_safety();
	test_end_to_end_current_room_fight();
	test_end_to_end_auto_skill_perform();
	test_end_to_end_empty_room_switch();
	test_roam_wait_and_backtrack_guard();
	test_end_to_end_smart_route_fight();
	test_end_to_end_auto_rest();
	test_end_to_end_auto_sell();
	test_integration_wiring();
	werror("\n自动挂机测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"] == 0 ? 0 : 1;
}
