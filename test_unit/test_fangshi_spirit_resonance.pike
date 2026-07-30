#!/usr/bin/env pike
/**
 * 方士职业天赋“灵契共鸣”运行时测试。
 *
 * 覆盖：
 * - 非方士与无召唤拒绝
 * - 虎、鹤、龟三灵组合效果
 * - 同房间队伍治疗与净化
 * - 三灵共鸣仙力恢复与独立冷却
 * - 单灵、无队伍时只影响自己
 * - summon 命令入口
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
	werror("\n[方士灵契共鸣 %d] %s\n", test_results["total"], name);
}

void test_pass()
{
	test_results["passed"]++;
	werror("  ✓ 通过\n");
}

void test_fail(string reason)
{
	test_results["failed"]++;
	werror("  ✗ 失败: %s\n", reason);
}

object create_test_player(string player_name, string race_id,
	string profession_id, int player_level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;

	player->set_name(player_name);
	player->name_cn = "灵契测试角色";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race_id);
	player->set_profeId(profession_id);
	player->setup_player(race_id, profession_id);
	player->level = player_level;
	player->set_att_by_level();
	return player;
}

void destroy_test_player(object|zero player)
{
	if(!player)
		return;
	SUMMOND->player_logout(player->query_name());
	destruct(player);
}

void test_profession_and_summon_limits()
{
	test_start("仅方士且有在场灵兽时可以发动");
	object|zero fangshi = 0;
	object|zero yushi = 0;
	object|zero room = 0;
	mapping no_summon_result = ([]);
	mapping profession_result = ([]);
	string error_desc = "";

	mixed err = catch {
		room = (object)(ROOT +
			"/gamelib/d/congxianzhen/congxianzhenguangchang");
		fangshi = create_test_player(
			"__testunit_resonance_empty__", "third", "fangshi", 30);
		yushi = create_test_player(
			"__testunit_resonance_yushi__", "human", "yushi", 30);
		if(fangshi && yushi && room){
			fangshi->move(room);
			yushi->move(room);
			no_summon_result = SUMMOND->activate_resonance(fangshi);
			profession_result = SUMMOND->activate_resonance(yushi);
		}
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && no_summon_result["success"] == 0 &&
	   no_summon_result["reason"] == "no_summon" &&
	   profession_result["success"] == 0 &&
	   profession_result["reason"] == "profession")
		test_pass();
	else
		test_fail("职业或召唤条件未正确限制: " + error_desc);

	destroy_test_player(fangshi);
	destroy_test_player(yushi);
}

void test_three_spirit_resonance()
{
	test_start("三灵共鸣同时触发冷却、治疗、净化和仙力恢复");
	string player_name = "__testunit_resonance_master__";
	object|zero player = 0;
	object|zero member = 0;
	object|zero dead_member = 0;
	object|zero outsider = 0;
	object|zero room = 0;
	mapping state = ([]);
	mapping result = ([]);
	mapping second_result = ([]);
	int summon_count = 0;
	int player_life_before = 0;
	int member_life_before = 0;
	int outsider_life_before = 0;
	string error_desc = "";

	mixed err = catch {
		room = (object)(ROOT +
			"/gamelib/d/congxianzhen/congxianzhenguangchang");
		player = create_test_player(
			player_name, "third", "fangshi", 60);
		member = create_test_player(
			"__testunit_resonance_member__", "third", "fangshi", 60);
		dead_member = create_test_player(
			"__testunit_resonance_dead_member__",
			"third", "fangshi", 60);
		outsider = create_test_player(
			"__testunit_resonance_outsider__",
			"human", "yushi", 60);
		if(player && member && dead_member && outsider && room){
			player->skills["huling"] = ({10,0});
			player->skills["heling"] = ({10,0});
			player->skills["guiling"] = ({5,0});
			player->skills["sanlingheyi"] = ({3,0});
			player->skills["hanbingzhou"] = ({1,0});
			player->set_term("__testunit_resonance_team__");
			member->set_term("__testunit_resonance_team__");
			dead_member->set_term("__testunit_resonance_team__");
			player->move(room);
			member->move(room);
			dead_member->move(room);
			outsider->move(room);

			player_life_before = player->query_life_max()/4;
			member_life_before = member->query_life_max()/4;
			outsider_life_before = outsider->query_life_max()/4;
			player->set_life(player_life_before);
			member->set_life(member_life_before);
			dead_member->set_life(0);
			outsider->set_life(outsider_life_before);
			player->set_mofa(0);
			player->timeCold = 2;
			player->f_skills["lingren"] = 20;
			player->f_skills["lingzhi"] = 5;
			player->f_skills["hanbingzhou"] = 20;
			player->set_debuff("dot",0,"test_dot");
			player->set_debuff("dot",1,10);
			player->set_debuff("dot",2,10);
			player->set_debuff("curse",0,"attack");
			player->set_debuff("curse",1,10);
			player->set_debuff("curse",2,10);
			member->set_debuff("curse2",0,"shenzhishufu");
			member->set_debuff("curse2",1,1);
			member->set_debuff("curse2",2,10);
			dead_member->set_debuff("curse",0,"attack");
			dead_member->set_debuff("curse",1,10);
			dead_member->set_debuff("curse",2,10);
			outsider->set_debuff("curse",0,"attack");
			outsider->set_debuff("curse",1,10);
			outsider->set_debuff("curse",2,10);

			summon_count =
				SUMMOND->summon_all_spirits(player_name, 600, 3);
			state = SUMMOND->get_resonance_state(player);
			result = SUMMOND->activate_resonance(player);
			player["/tmp/fangshi/resonance_until"] = 0;
			second_result = SUMMOND->activate_resonance(player);
		}
	};
	if(err)
		error_desc = describe_error(err);

	int valid = !err && player && member && dead_member && outsider &&
		summon_count == 3 &&
		state["count"] == 3 && state["perfect"] == 1 &&
		result["success"] == 1 && result["perfect"] == 1 &&
		result["huling"] == 1 && result["heling"] == 1 &&
		result["guiling"] == 1 &&
		result["cooldown"] == 120 &&
		result["cooldown_seconds"] == 6 &&
		result["cooldown_skills"] == 2 &&
		result["heal_percent"] == 15 &&
		SUMMOND->get_resonance_skill_level(player, "huling") == 5 &&
		SUMMOND->get_resonance_skill_level(player, "heling") == 5 &&
		player->f_skills["lingren"] == 14 &&
		player->f_skills["lingzhi"] == 1 &&
		player->f_skills["hanbingzhou"] == 20 &&
		player->get_cur_life() > player_life_before &&
		member->get_cur_life() > member_life_before &&
		result["healed_members"] == 2 &&
		result["cleansed"] == 3 &&
		player->query_debuff("dot",0) == "none" &&
		player->query_debuff("curse",0) == "none" &&
		member->query_debuff("curse2",0) == "none" &&
		dead_member->get_cur_life() == 0 &&
		dead_member->query_debuff("curse",0) == "attack" &&
		outsider->get_cur_life() == outsider_life_before &&
		outsider->query_debuff("curse",0) == "attack" &&
		player->get_cur_mofa() > 0 &&
		player->timeCold == 0 &&
		SUMMOND->get_current_summon_count(player_name) == 3 &&
		second_result["success"] == 0 &&
		second_result["reason"] == "cooldown" &&
		second_result["cooldown"] > 0 &&
		(int)player["/plus/fangshi/resonance_until"] > time();

	if(valid)
		test_pass();
	else
		test_fail("三灵组合效果或冷却保护失败: " + error_desc);

	destroy_test_player(player);
	destroy_test_player(member);
	destroy_test_player(dead_member);
	destroy_test_player(outsider);
}

void test_dead_fangshi_rejected()
{
	test_start("死亡方士不能借共鸣自我复活");
	string player_name = "__testunit_resonance_dead__";
	object|zero player = 0;
	object|zero room = 0;
	object|zero crane = 0;
	mapping result = ([]);
	string error_desc = "";

	mixed err = catch {
		room = (object)(ROOT +
			"/gamelib/d/congxianzhen/congxianzhenguangchang");
		player = create_test_player(
			player_name, "third", "fangshi", 30);
		if(player && room){
			player->skills["heling"] = ({2,0});
			player->move(room);
			crane = SUMMOND->summon_creature(
				player_name, "heling", 600, 2);
			player->set_life(0);
			result = SUMMOND->activate_resonance(player);
		}
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && player && crane &&
	   result["success"] == 0 &&
	   result["reason"] == "dead" &&
	   player->get_cur_life() == 0)
		test_pass();
	else
		test_fail("死亡状态仍能发动共鸣: " + error_desc);

	destroy_test_player(player);
}

void test_turtle_control_balance()
{
	test_start("单龟契不解除技能封禁且使用90秒冷却");
	string player_name = "__testunit_resonance_turtle__";
	object|zero player = 0;
	object|zero room = 0;
	object|zero turtle = 0;
	mapping result = ([]);
	string error_desc = "";

	mixed err = catch {
		room = (object)(ROOT +
			"/gamelib/d/congxianzhen/congxianzhenguangchang");
		player = create_test_player(
			player_name, "third", "fangshi", 30);
		if(player && room){
			player->skills["guiling"] = ({2,0});
			player->move(room);
			player->set_debuff("dot",0,"test_dot");
			player->set_debuff("dot",1,10);
			player->set_debuff("dot",2,10);
			player->set_debuff("curse",0,"attack");
			player->set_debuff("curse",1,10);
			player->set_debuff("curse",2,10);
			player->set_debuff("curse2",0,"shenzhishufu");
			player->set_debuff("curse2",1,1);
			player->set_debuff("curse2",2,10);
			turtle = SUMMOND->summon_creature(
				player_name, "guiling", 600, 2);
			result = SUMMOND->activate_resonance(player);
		}
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && player && turtle &&
	   result["success"] == 1 &&
	   result["perfect"] == 0 &&
	   result["cooldown"] == 90 &&
	   result["cleansed"] == 2 &&
	   player->query_debuff("dot",0) == "none" &&
	   player->query_debuff("curse",0) == "none" &&
	   player->query_debuff("curse2",0) == "shenzhishufu")
		test_pass();
	else
		test_fail("普通龟契净化范围或冷却不正确: " + error_desc);

	destroy_test_player(player);
}

void test_solo_crane_resonance()
{
	test_start("没有队伍时鹤契只治疗方士自己");
	string player_name = "__testunit_resonance_solo__";
	object|zero player = 0;
	object|zero room = 0;
	object|zero crane = 0;
	mapping result = ([]);
	int life_before = 0;
	string error_desc = "";

	mixed err = catch {
		room = (object)(ROOT +
			"/gamelib/d/congxianzhen/congxianzhenguangchang");
		player = create_test_player(
			player_name, "third", "fangshi", 30);
		if(player && room){
			player->skills["heling"] = ({2,0});
			player->move(room);
			life_before = player->query_life_max()/3;
			player->set_life(life_before);
			crane = SUMMOND->summon_creature(
				player_name, "heling", 600, 2);
			result = SUMMOND->activate_resonance(player);
		}
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && player && crane &&
	   result["success"] == 1 &&
	   result["count"] == 1 &&
	   result["heling"] == 1 &&
	   result["perfect"] == 0 &&
	   result["cooldown"] == 90 &&
	   result["heal_percent"] == 7 &&
	   result["healed_members"] == 1 &&
	   result["mofa_restored"] == 0 &&
	   player->get_cur_life() > life_before)
		test_pass();
	else
		test_fail("单人鹤契治疗不正确: " + error_desc);

	destroy_test_player(player);
}

void test_advanced_replacement_keeps_summoning()
{
	test_start("高级技能替换后仍可召虎灵和三灵齐出");
	string player_name = "__testunit_resonance_advanced__";
	object|zero player = 0;
	object|zero room = 0;
	object|zero book = 0;
	object|zero summon_command = 0;
	object|zero original_player = this_player();
	mapping summons = ([]);
	int tiger_level = 0;
	int all_count = 0;
	int failed = 0;
	string error_desc = "";

	mixed err = catch {
		room = (object)(ROOT +
			"/gamelib/d/congxianzhen/congxianzhenguangchang");
		player = create_test_player(
			player_name, "third", "fangshi", 100);
		summon_command =
			(object)(ROOT + "/gamelib/cmds/summon.pike");
		if(player && room && summon_command){
			player->move(room);
			set_this_player(player);

			player->skills["huling"] = ({4,0});
			book = clone(ROOT +
				"/gamelib/clone/item/book/huling_mystic");
			if(!book || book->read() != 1 ||
			   player->skills["huling"] ||
			   !player->skills["huling_mystic"])
				failed++;
			else
				player->skills["huling_mystic"][0] = 4;

			summon_command->main("huling");
			summons = SUMMOND->get_player_summons(player_name);
			if(!summons["huling"])
				failed++;
			tiger_level =
				SUMMOND->get_resonance_skill_level(player, "huling");
			SUMMOND->dismiss_all(player_name);

			player->skills["sanlingheyi"] = ({3,0});
			book = clone(ROOT +
				"/gamelib/clone/item/book/sanlingheyi2");
			if(!book || book->read() != 1 ||
			   player->skills["sanlingheyi"] ||
			   !player->skills["sanlingheyi2"])
				failed++;

			summon_command->main("all");
			all_count = SUMMOND->get_current_summon_count(player_name);
		}
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err && player && failed == 0 &&
	   tiger_level == 4 && all_count == 3)
		test_pass();
	else
		test_fail(sprintf(
			"高级替换召唤失败=%d, 虎灵等级=%d, 三灵=%d: %s",
			failed, tiger_level, all_count, error_desc));

	if(book)
		destruct(book);
	destroy_test_player(player);
}

void test_command_wiring()
{
	test_start("召唤面板包含灵契共鸣入口与说明");
	string command_path = ROOT + "/gamelib/cmds/summon.pike";
	string source = Stdio.read_file(command_path);
	string skills_source =
		Stdio.read_file(ROOT + "/gamelib/cmds/myskills.pike");
	program|zero command_program = 0;
	program|zero skills_program = 0;
	mixed err = catch {
		command_program = (program)command_path;
		skills_program =
			(program)(ROOT + "/gamelib/cmds/myskills.pike");
	};

	if(!err && command_program && skills_program && source && skills_source &&
	   search(source, "[发动灵契共鸣:summon resonance]") != -1 &&
	   search(source, "虎契·破军") != -1 &&
	   search(source, "鹤契·回春") != -1 &&
	   search(source, "龟契·净厄") != -1 &&
	   search(skills_source,
		"[方士专属·灵契共鸣:summon list]") != -1)
		test_pass();
	else
		test_fail("召唤面板未完整接入灵契共鸣");
}

void print_summary()
{
	werror("\n========================================\n");
	werror("方士灵契共鸣测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"], test_results["passed"], test_results["failed"]);
	werror("========================================\n");
}

void run_tests()
{
	test_profession_and_summon_limits();
	test_three_spirit_resonance();
	test_dead_fangshi_rejected();
	test_turtle_control_balance();
	test_solo_crane_resonance();
	test_advanced_replacement_keeps_summoning();
	test_command_wiring();
	print_summary();
}

int main()
{
	run_tests();
	return test_results["failed"] == 0 ? 0 : 1;
}
