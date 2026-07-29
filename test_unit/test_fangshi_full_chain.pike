#!/usr/bin/env pike
/**
 * 方士全链路测试：
 * 建角配置 -> 真实玩家对象 -> 技能书学习 -> 全技能/书籍 ->
 * 召唤守护进程 -> 装备兼容 -> 登录与界面接线。
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
	werror("\n[方士全链路 %d] %s\n", test_results["total"], name);
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

void test_character_creation_config()
{
	test_start("建角入口与初始技能配置");
	string content = Stdio.read_file(ROOT + "/gamelib/d/init");
	int valid = content &&
		search(content, "[中立:choice_race third]") != -1 &&
		search(content, "[方士:choice_profe third/fangshi]") != -1 &&
		search(content, "setup_player(\"third\",u_p)") != -1 &&
		search(content, "skills[\"lingdanshu\"]") != -1 &&
		search(content, "skills[\"lingzhihun\"]") != -1 &&
		search(content, "query_base_all()==0") != -1 &&
		search(content, "[进入游戏:start third]") != -1 &&
		search(content, "m_delete(me->skills,\"lingshu\")") != -1;

	if(valid)
		test_pass();
	else
		test_fail("建角入口、初始技能或旧角色迁移未完整接线");
}

object create_runtime_fangshi(string player_name, int player_level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;

	player->set_name(player_name);
	player->name_cn = "测试方士";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third", "fangshi");
	player->level = player_level;
	player->set_att_by_level();
	player->skills["lingdanshu"] = ({1,0});
	return player;
}

void destroy_runtime_player(object|zero player)
{
	if(!player)
		return;
	SUMMOND->player_logout(player->query_name());
	destruct(player);
}

void test_runtime_character_and_learning()
{
	test_start("真实方士对象与技能书学习");
	object|zero player = 0;
	object|zero book = 0;
	object|zero original_player = this_player();
	int read_result = 0;
	string error_desc = "";
	mixed err = catch {
		player = create_runtime_fangshi("__testunit_fangshi_create__", 30);
		if(player){
			book = clone(ROOT + "/gamelib/clone/item/book/lingren");
			set_this_player(player);
			read_result = book->read();
		}
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	int valid = player &&
		player->query_raceId() == "third" &&
		player->query_profeId() == "fangshi" &&
		player->query_race_cn("third") == "中立" &&
		player->query_profe_cn("fangshi") == "方士" &&
		player->query_str() == 53 &&
		player->query_dex() == 28 &&
		player->query_think() == 70 &&
		player->query_life_max() > 0 &&
		player->query_mofa_max() > 0 &&
		player->skills["lingdanshu"] &&
		read_result == 1 &&
		player->skills["lingren"];

	if(valid)
		test_pass();
	else
		test_fail("真实建角或读书失败: " + error_desc);

	if(book)
		destruct(book);
	destroy_runtime_player(player);
}

void test_upgrade_books_runtime()
{
	test_start("二级与强化技能书前置替换学习");
	object|zero player = 0;
	object|zero book = 0;
	object|zero original_player = this_player();
	mapping(string:array(string)) enhanced_books = ([
		"lingbailei11":({"lingbailei11","lingbailei"}),
		"lingxuanying2":({"lingxuanying2","lingxuanying"}),
		"sanlingheyi2":({"sanlingheyi2","sanlingheyi"}),
		"lingchuanxin2":({"lingchuanxin2","lingchuanxin"}),
	]);
	int failed = 0;
	string links = "";
	string error_desc = "";

	mixed err = catch {
		player = create_runtime_fangshi("__testunit_fangshi_books__", 100);
		if(player){
			set_this_player(player);
			book = clone(ROOT + "/gamelib/clone/item/book/huling1");
			if(book)
				links = book->query_inventory_links(1);
			if(!book || book->read() != 1)
				failed++;

			book = clone(ROOT + "/gamelib/clone/item/book/huling2");
			if(!book || book->read() != 1 ||
			   !player->skills["huling"] ||
			   player->skills["huling"][0] != 2)
				failed++;

			foreach(sort(indices(enhanced_books)), string book_name){
				string skill_name = enhanced_books[book_name][0];
				string old_skill = enhanced_books[book_name][1];
				book = clone(ROOT + "/gamelib/clone/item/book/" + book_name);
				if(!book || book->read() != 5)
					failed++;
				player->skills[old_skill] = ({1,0});
				if(!book || book->read() != 1 ||
				   !player->skills[skill_name] ||
				   player->skills[old_skill])
					failed++;
			}
		}
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err && player && failed == 0 &&
	   search(links, "[学习:read ") != -1)
		test_pass();
	else
		test_fail(sprintf("技能书升级失败=%d: %s", failed, error_desc));

	if(book)
		destruct(book);
	destroy_runtime_player(player);
}

void test_all_configured_skills_and_books()
{
	test_start("全部方士技能与技能书运行时加载");
	string csv = Stdio.read_file(ROOT + "/gamelib/data/can_buy_book_list.csv");
	int checked = 0;
	int failed = 0;

	if(csv){
		foreach(csv / "\n", string line){
			array(string) parts = line / ",";
			if(sizeof(parts) < 4 || parts[3] != "fangshi")
				continue;

			string book_path = ROOT + "/gamelib/clone/item/" + parts[1];
			object|zero book = 0;
			object|zero skill = 0;
			mixed err = catch {
				book = clone(book_path);
				if(book && book->skill_bname)
					skill = (object)(ROOT + "/gamelib/single/skills/" +
						book->skill_bname);
			};

			checked++;
			if(err || !book || !skill ||
			   (book->profe_read_limit != "fangshi" &&
			    book->profe_read_limit != "方士") ||
			   search(skill->skill_type, "fangshi") == -1){
				failed++;
				werror("  ✗ 配置失败: %s (%s)\n",
					parts[1], err ? describe_error(err) : "属性不完整");
			}
			if(book)
				destruct(book);
		}
	}

	if(checked >= 44 && failed == 0)
		test_pass();
	else
		test_fail(sprintf("配置技能书=%d, 失败=%d", checked, failed));
}

void test_mystic_skills_runtime()
{
	test_start("五个神秘技能购买配置与替换学习");
	mapping(string:string) skill_names = ([
		"lingxuan_mystic":"lingxuan",
		"linghuoshao_mystic":"linghuoshao",
		"lingzhi_mystic":"lingzhi",
		"lingdun_mystic":"lingdun",
		"huling_mystic":"huling",
	]);
	object|zero player = 0;
	object|zero book = 0;
	object|zero original_player = this_player();
	int failed = 0;
	string error_desc = "";

	mixed err = catch {
		player = create_runtime_fangshi("__testunit_fangshi_mystic__", 100);
		if(player)
			set_this_player(player);
		foreach(sort(indices(skill_names)), string skill_name){
			string old_skill = skill_names[skill_name];
			object|zero skill = 0;
			array store_info =
				BUYD->query_hl_book_info("book/" + skill_name);
			skill = (object)(ROOT + "/gamelib/single/skills/" + skill_name);
			book = clone(ROOT + "/gamelib/clone/item/book/" + skill_name);
			if(!skill || !book || skill->skill_rare != "mystic" ||
			   search(skill->skill_type, "fangshi") == -1 ||
			   !store_info || sizeof(store_info) != 3 ||
			   store_info[1] != 2 || store_info[2] != 790 ||
			   book->read() != 5){
				failed++;
				continue;
			}
			player->skills[old_skill] = ({1,0});
			if(book->read() != 1 || !player->skills[skill_name] ||
			   player->skills[old_skill])
				failed++;
		}
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err && player && failed == 0)
		test_pass();
	else
		test_fail(sprintf(
			"%d 个神秘技能购买或替换学习失败: %s", failed, error_desc));

	if(book)
		destruct(book);
	destroy_runtime_player(player);
}

void test_passive_skill_growth_runtime()
{
	test_start("灵智魂五级被动成长与世界掉落");
	object|zero player = 0;
	object|zero book = 0;
	object|zero original_player = this_player();
	int failed = 0;
	string error_desc = "";
	string drop_source =
		Stdio.read_file(ROOT + "/gamelib/data/specItems.list");

	mixed err = catch {
		player = create_runtime_fangshi("__testunit_fangshi_passive__", 100);
		if(player){
			set_this_player(player);
			for(int level = 1; level <= 5; level++){
				string suffix = level == 1 ? "" : (string)level;
				book = clone(ROOT + "/gamelib/clone/item/book/lingzhihun" +
					suffix);
				if(!book || book->read() != 1 ||
				   !player->skills["lingzhihun"] ||
				   player->skills["lingzhihun"][0] != level ||
				   player->query_base_all() !=
					MUD_SKILLSD["lingzhihun"]->query_performs_attack(level))
					failed++;
			}
		}
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	int drops_valid = drop_source &&
		search(drop_source, "book/lingzhihun2") != -1 &&
		search(drop_source, "book/lingzhihun3") != -1 &&
		search(drop_source, "book/lingzhihun4") != -1 &&
		search(drop_source, "book/lingzhihun5") != -1;

	if(!err && player && failed == 0 && drops_valid)
		test_pass();
	else
		test_fail(sprintf(
			"被动成长失败=%d, 掉落=%d: %s",
			failed, drops_valid, error_desc));

	if(book)
		destruct(book);
	destroy_runtime_player(player);
}

void test_high_level_skill_growth_contract()
{
	test_start("高级技能五级成长数据完整");
	array(string) skill_names = ({
		"lingchuanxin2",
		"lingxuanying2",
		"sanlingheyi2",
		"linglieshou",
	});
	int failed = 0;

	foreach(skill_names, string skill_name){
		object|zero skill = 0;
		mixed err = catch {
			skill = (object)(ROOT + "/gamelib/single/skills/" + skill_name);
		};
		mapping limits = ([]);
		if(skill && skill->query_performs_level_limit_all)
			limits = skill->query_performs_level_limit_all();
		if(err || !skill || !limits || sizeof(limits) != 5){
			failed++;
			continue;
		}
		for(int level = 1; level <= 5; level++){
			if(skill->query_performs_attack(level) <= 0 ||
			   skill->query_performs_cast(level) <= 0 ||
			   !limits[level])
				failed++;
		}
	}

	if(failed == 0)
		test_pass();
	else
		test_fail(sprintf("%d 个高级技能成长字段缺失", failed));
}

void test_skill_descriptions_match_runtime()
{
	test_start("技能说明与战斗引擎效果一致");
	mapping(string:array(string)) forbidden_words = ([
		"lingbailei":({"范围内所有敌人","麻痹"}),
		"lingbailei11":({"范围内所有敌人","麻痹"}),
		"lingchuanxin":({"无视"}),
		"lingchuanxin2":({"无视"}),
		"lingdun":({"免疫"}),
		"lingdun_mystic":({"反弹"}),
		"linghundaji":({"眩晕"}),
		"linghuoshao":({"总伤害","%防御"}),
		"linghuoshao_mystic":({"总伤害","攻击和防御"}),
		"linghuti":({"反弹"}),
		"lingji":({"双倍伤害"}),
		"lingqishu":({"多个敌人"}),
		"lingqun":({"多个敌人","减速"}),
		"lingren":({"降低","%防御"}),
		"lingshenhushu":({"吸收","转化为生命"}),
		"lingxishu":({"恢复"}),
		"lingxuan":({"所有敌人"}),
		"lingxuan_mystic":({"混乱"}),
		"lingyichu":({"流血"}),
		"lingzhi_mystic":({"清除"}),
	]);
	int failed = 0;

	foreach(sort(indices(forbidden_words)), string skill_name){
		object|zero skill = 0;
		mixed err = catch {
			skill = (object)(ROOT + "/gamelib/single/skills/" + skill_name);
		};
		if(err || !skill){
			failed++;
			continue;
		}
		string text = skill->query_desc();
		for(int level = 1; level <= 10; level++)
			text += skill->query_performs_desc(level);
		foreach(forbidden_words[skill_name], string word){
			if(search(text, word) != -1)
				failed++;
		}
	}

	if(failed == 0)
		test_pass();
	else
		test_fail(sprintf("%d 处技能说明仍宣称未实现效果", failed));
}

void test_heal_and_life_buff_runtime()
{
	test_start("治疗、减疗与生命上限增益运行时生效");
	object|zero player = 0;
	object|zero enemy_player = 0;
	object|zero team_player = 0;
	object|zero room = 0;
	int life_after_heal = 0;
	int life_after_reduced_heal = 0;
	int team_life_after_heal = 0;
	int mofa_before = 0;
	int mofa_after = 0;
	int life_limit_before = 0;
	int life_limit_after = 0;
	string error_desc = "";

	mixed err = catch {
		player = create_runtime_fangshi("__testunit_fangshi_heal__", 30);
		enemy_player = create_runtime_fangshi(
			"__testunit_fangshi_heal_enemy__", 30);
		team_player = create_runtime_fangshi(
			"__testunit_fangshi_heal_team__", 30);
		room = (object)(ROOT +
			"/gamelib/d/congxianzhen/congxianzhenguangchang");
		if(player && enemy_player && team_player && room){
			player->move(room);
			enemy_player->move(room);
			team_player->move(room);
			player->skills["lingzhi"] = ({2,0});
			player->set_life(100);
			player->set_mofa(player->query_mofa_max());
			mofa_before = player->get_cur_mofa();
			player->_fight(enemy_player);
			player->perform("lingzhi", 1);
			life_after_heal = player->get_cur_life();
			mofa_after = player->get_cur_mofa();

			player->f_skills["lingzhi"] = 0;
			player->timeCold = 0;
			player->set_life(100);
			player->set_debuff("curse",0,"life");
			player->set_debuff("curse",1,50);
			player->set_debuff("curse",2,10);
			player->perform("lingzhi", 1);
			life_after_reduced_heal = player->get_cur_life();

			player->f_skills["linglianpu"] = 0;
			player->timeCold = 0;
			player->clean_debuff("curse");
			player->skills["linglianpu"] = ({1,0});
			player->set_term("__testunit_fangshi_team__");
			team_player->set_term("__testunit_fangshi_team__");
			player->set_life(100);
			team_player->set_life(100);
			player->perform("linglianpu", 1);
			team_life_after_heal = team_player->get_cur_life();

			player->_clean_fight();
			life_limit_before = player->query_life_max();
			player->set_buff("buff",0,"life_max");
			player->set_buff("buff",1,500);
			player->set_buff("buff",2,10);
			life_limit_after = player->query_life_max();
		}
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && player && enemy_player && team_player && room &&
	   life_after_heal == 600 &&
	   mofa_after == mofa_before-70 &&
	   life_after_reduced_heal == 350 &&
	   team_life_after_heal == 600 &&
	   life_limit_after == life_limit_before+500)
		test_pass();
	else
		test_fail(sprintf(
			"治疗或生命增益未实际生效: life=%d reduced=%d team=%d mofa=%d/%d max=%d/%d %s",
			life_after_heal, life_after_reduced_heal, team_life_after_heal,
			mofa_before, mofa_after,
			life_limit_before, life_limit_after, error_desc));

	if(player)
		player->_clean_fight();
	if(enemy_player)
		enemy_player->_clean_fight();
	if(team_player)
		team_player->_clean_fight();
	destroy_runtime_player(player);
	destroy_runtime_player(enemy_player);
	destroy_runtime_player(team_player);
}

void test_summon_daemon_runtime()
{
	test_start("召唤守护进程真实创建、上限与清理");
	string player_name = "__testunit_fangshi_summon__";
	object|zero player = 0;
	object|zero original_player = this_player();
	object|zero room = 0;
	object|zero tiger = 0;
	object|zero crane = 0;
	object|zero turtle = 0;
	int all_count = 0;
	string error_desc = "";

	mixed err = catch {
		player = create_runtime_fangshi(player_name, 30);
		room = (object)(ROOT +
			"/gamelib/d/congxianzhen/congxianzhenguangchang");
		if(player && room){
			player->move(room);
			tiger = SUMMOND->summon_creature(player_name, "huling", 600, 2);
			crane = SUMMOND->summon_creature(player_name, "heling", 600, 2);
			turtle = SUMMOND->summon_creature(player_name, "guiling", 600, 2);
		}
	};
	if(err)
		error_desc = describe_error(err);

	int first_stage = player && room && tiger && crane && !turtle &&
		SUMMOND->get_current_summon_count(player_name) == 2 &&
		tiger->query_summon_type() == "huling" &&
		tiger->query_master() == player_name &&
		!tiger->can_be_attacked(player) &&
		tiger->query_life_max() > 0;

	mixed second_err = catch {
		if(player){
			SUMMOND->dismiss_all(player_name);
			player->level = 60;
			all_count = SUMMOND->summon_all_spirits(
				player_name, 600, 3);
		}
	};
	if(second_err)
		error_desc += describe_error(second_err);

	int second_stage = all_count == 3 &&
		SUMMOND->get_current_summon_count(player_name) == 3;
	SUMMOND->player_logout(player_name);
	int cleanup_stage =
		SUMMOND->get_current_summon_count(player_name) == 0;

	if(!err && !second_err && first_stage && second_stage && cleanup_stage)
		test_pass();
	else
		test_fail("召唤创建、数量限制或下线清理失败: " + error_desc);

	destroy_runtime_player(player);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
}

void test_equipment_runtime()
{
	test_start("方士武器与防具运行时兼容");
	array(string) item_paths = ({
		ROOT + "/gamelib/clone/item/weapon/5shanmuchangzhang/5shanmuchangzhang",
		ROOT + "/gamelib/clone/item/armor/10lupimao/10lupimao",
	});
	int checked = 0;
	int failed = 0;

	foreach(item_paths, string item_path){
		object|zero item = 0;
		mixed err = catch {
			item = clone(item_path);
		};
		if(err || !item ||
		   search(item->query_item_profeLimit(), "fangshi") == -1)
			failed++;
		else
			checked++;
		if(item)
			destruct(item);
	}

	if(checked == sizeof(item_paths) && failed == 0)
		test_pass();
	else
		test_fail(sprintf("已验证装备=%d, 失败=%d", checked, failed));
}

void test_teacher_learning_link_runtime()
{
	test_start("方士传人技能学习按钮运行时输出");
	object|zero player = 0;
	object|zero teacher = 0;
	object|zero original_player = this_player();
	string links = "";
	string error_desc = "";
	mixed err = catch {
		player = create_runtime_fangshi("__testunit_fangshi_teacher__", 1);
		teacher = clone(ROOT + "/gamelib/clone/npc/fangshi_teacher.pike");
		if(player && teacher){
			set_this_player(player);
			links = teacher->query_npc_links(0);
		}
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);

	if(!err && player && teacher &&
	   search(links, "[学习方士技能:buy_items book fangshi]") != -1)
		test_pass();
	else
		test_fail("NPC详情页没有输出学习按钮: " + error_desc);

	if(teacher)
		destruct(teacher);
	destroy_runtime_player(player);
}

void test_system_wiring()
{
	test_start("界面、战斗和生命周期接线");
	string init_source = Stdio.read_file(ROOT + "/gamelib/d/init");
	string skills_source = Stdio.read_file(ROOT + "/gamelib/cmds/myskills.pike");
	string kill_source = Stdio.read_file(ROOT + "/lowlib/wapmud2/cmds/kill.pike");
	string quick_source = Stdio.read_file(ROOT +
		"/lowlib/wapmud2/cmds/kill_quick.pike");
	string user_source = Stdio.read_file(ROOT + "/gamelib/clone/user.pike");
	string yushi_source = Stdio.read_file(ROOT +
		"/gamelib/cmds/yushi_myzone.pike");
	string create_skill_source = Stdio.read_file(ROOT +
		"/gamelib/single/create_skill.pike");
	program|zero kill_program = 0;
	program|zero quick_program = 0;
	program|zero skills_program = 0;
	program|zero yushi_program = 0;
	mixed err = catch {
		kill_program = (program)(ROOT + "/lowlib/wapmud2/cmds/kill.pike");
		quick_program = (program)(ROOT +
			"/lowlib/wapmud2/cmds/kill_quick.pike");
		skills_program = (program)(ROOT + "/gamelib/cmds/myskills.pike");
		yushi_program = (program)(ROOT + "/gamelib/cmds/yushi_myzone.pike");
	};

	int valid = !err && kill_program && quick_program && skills_program &&
		yushi_program &&
		init_source && skills_source && kill_source && quick_source && user_source &&
		yushi_source && create_skill_source &&
		search(skills_source, "[召唤灵兽:summon]") != -1 &&
		search(yushi_source,
			"[高级技能书:yushi_buy_hlbook_list]") != -1 &&
		search(kill_source, "query_raceId()==\"third\"") != -1 &&
		search(kill_source, "can_be_attacked") != -1 &&
		search(quick_source, "can_be_attacked") != -1 &&
		search(user_source, "SUMMOND->player_logout") != -1 &&
		search(create_skill_source, "\"方士\":\"fangshi\"") != -1;

	if(valid)
		test_pass();
	else
		test_fail("技能页、战斗或下线召唤清理未完整接线");
}

void print_summary()
{
	werror("\n========================================\n");
	werror("方士全链路测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"], test_results["passed"], test_results["failed"]);
	werror("========================================\n");
}

void run_tests()
{
	test_character_creation_config();
	test_runtime_character_and_learning();
	test_upgrade_books_runtime();
	test_all_configured_skills_and_books();
	test_mystic_skills_runtime();
	test_passive_skill_growth_runtime();
	test_high_level_skill_growth_contract();
	test_skill_descriptions_match_runtime();
	test_heal_and_life_buff_runtime();
	test_summon_daemon_runtime();
	test_equipment_runtime();
	test_teacher_learning_link_runtime();
	test_system_wiring();
	print_summary();
}

int main()
{
	run_tests();
	return test_results["failed"];
}
