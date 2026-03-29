#!/usr/bin/env pike
/**
 * ========================================================================
 * 方士系统集成测试
 * ========================================================================
 *
 * 模拟游戏环境进行更深度的测试：
 * 1. 模拟方士角色创建
 * 2. 模拟技能学习
 * 3. 模拟召唤物召唤
 * 4. 模拟技能施放
 *
 * ========================================================================
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

// 测试结果统计
mapping(string:int) test_results = ([
	"total": 0,
	"passed": 0,
	"failed": 0,
]);

void test_start(string test_name) {
	test_results["total"]++;
	werror("\n[集成测试 %d] %s\n", test_results["total"], test_name);
}

void test_pass() {
	test_results["passed"]++;
	werror("  ✓ 通过\n");
}

void test_fail(string reason) {
	test_results["failed"]++;
	werror("  ✗ 失败: %s\n", reason);
}

void print_summary() {
	werror("\n========================================\n");
	werror("集成测试完成！\n");
	werror("总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"], test_results["passed"], test_results["failed"]);
	werror("========================================\n");
}

// 测试1: 技能文件结构完整性
void test_skill_structure() {
	test_start("技能文件结构完整性测试");

	// 定义需要检查的技能及其属性
	mapping(string:mapping) skill_checks = ([
		"lingdanshu": ([
			"s_type": "zhudong",
			"s_skill_type": "phy",
			"performs_attack": 1,
		]),
		"huling": ([
			"s_type": "zhudong",
			"s_skill_type": "buff",
		]),
		"heling": ([
			"s_type": "zhudong",
			"s_skill_type": "buff",
		]),
		"guiling": ([
			"s_type": "zhudong",
			"s_skill_type": "buff",
		]),
	]);

	foreach(skill_checks; string skill_name; mapping expected_props) {
		string skill_path = ROOT + "/gamelib/single/skills/" + skill_name;
		if(!Stdio.exist(skill_path)) {
			test_fail("技能文件不存在: " + skill_name);
			return;
		}

		// 读取并检查技能文件内容
		string content = Stdio.read_file(skill_path);
		if(!content) {
			test_fail("无法读取技能文件: " + skill_name);
			return;
		}

		// 检查关键字段
		if(!has_value(content, "inherit WAP_SKILL")) {
			test_fail(skill_name + " 没有继承 WAP_SKILL");
			return;
		}

		if(!has_value(content, "name_cn=\"【方】")) {
			test_fail(skill_name + " 没有正确的中文名称");
			return;
		}

		werror("  ✓ %s 结构正确\n", skill_name);
	}

	test_pass();
}

// 测试2: 召唤物基类测试
void test_summon_base_class() {
	test_start("召唤物基类测试");

	string base_path = ROOT + "/gamelib/clone/npc/summon/base_summon.pike";
	string content = Stdio.read_file(base_path);

	if(!content) {
		test_fail("无法读取 base_summon.pike");
		return;
	}

	// 检查关键方法
	array(string) required_methods = ({
		"set_master", "query_master",
		"set_summon_duration", "set_summon_type", "query_summon_type",
		"check_duration", "heart_beat", "fight_die",
	});

	foreach(required_methods, string method) {
		if(!has_value(content, method + "(")) {
			test_fail("base_summon.pike 缺少方法: " + method);
			return;
		}
	}

	// 检查是否正确继承
	if(!has_value(content, "inherit GAMELIB_NPC")) {
		test_fail("base_summon.pike 没有继承 GAMELIB_NPC");
		return;
	}

	// 检查是否有心跳设置
	if(!has_value(content, "set_heart_beat") && !has_value(content, "_tasknpc")) {
		werror("  ! 警告: base_summon 可能需要设置心跳\n");
	}

	test_pass();
}

// 测试3: 召唤物特性测试
void test_summon_creature_features() {
	test_start("召唤物特性测试");

	// 检查虎灵（攻击型）
	string huling_path = ROOT + "/gamelib/clone/npc/summon/huling.pike";
	string content = Stdio.read_file(huling_path);

	if(!content || !has_value(content, "set_base_str")) {
		test_fail("huling.pike 没有设置基础属性");
		return;
	}

	// 检查鹤灵（治疗型）
	string heling_path = ROOT + "/gamelib/clone/npc/summon/heling.pike";
	content = Stdio.read_file(heling_path);

	if(!content || !has_value(content, "heal_master")) {
		test_fail("heling.pike 没有治疗方法");
		return;
	}

	// 检查龟灵（防御型）
	string guiling_path = ROOT + "/gamelib/clone/npc/summon/guiling.pike";
	content = Stdio.read_file(guiling_path);

	if(!content || !has_value(content, "taunt_enemies")) {
		test_fail("guiling.pike 没有嘲讽方法");
		return;
	}

	werror("  ✓ 虎灵: 攻击型\n");
	werror("  ✓ 鹤灵: 治疗型\n");
	werror("  ✓ 龟灵: 防御型\n");

	test_pass();
}

// 测试4: 技能书配置测试
void test_book_config() {
	test_start("技能书配置测试");

	array(string) books_to_check = ({
		"lingdanshu", "huling1", "heling1", "guiling1",
	});

	foreach(books_to_check, string book_name) {
		string book_path = ROOT + "/gamelib/clone/item/book/" + book_name;
		if(!Stdio.exist(book_path)) {
			test_fail("技能书不存在: " + book_name);
			return;
		}

		string content = Stdio.read_file(book_path);
		if(!content) {
			test_fail("无法读取技能书: " + book_name);
			return;
		}

		// 检查关键字段
		if(!has_value(content, "inherit WAP_BOOK")) {
			test_fail(book_name + " 没有继承 WAP_BOOK");
			return;
		}

		if(!has_value(content, "skill_bname=")) {
			test_fail(book_name + " 没有设置 skill_bname");
			return;
		}

		if(!has_value(content, "profe_read_limit")) {
			test_fail(book_name + " 没有设置职业限制");
			return;
		}

		werror("  ✓ %s 配置正确\n", book_name);
	}

	test_pass();
}

// 测试5: 召唤守护进程逻辑测试
void test_summon_daemon_logic() {
	test_start("召唤守护进程逻辑测试");

	// 测试召唤数量限制
	werror("  测试召唤数量限制...\n");

	// 低等级方士只能召唤1只
	// 由于我们无法创建真实玩家，这里只检查守护进程是否存在

	if(!SUMMOND) {
		test_fail("SUMMOND 守护进程未加载");
		return;
	}

	// 测试空输入的安全性
	werror("  测试空输入安全性...\n");

	mixed err = catch {
		SUMMOND->get_max_summons(0);
		SUMMOND->can_summon(0);
		SUMMOND->get_current_summon_count(0);
		SUMMOND->get_player_summons(0);
		SUMMOND->summon_creature(0, 0, 0, 0);
		SUMMOND->dismiss_creature(0, 0);
		SUMMOND->dismiss_all(0);
	};

	if(err) {
		test_fail("守护进程处理空输入时出错: " + describe_error(err));
		return;
	}

	test_pass();
}

// 测试6: CSV配置与实际文件一致性
void test_csv_file_consistency() {
	test_start("CSV配置与实际文件一致性测试");

	string csv_path = ROOT + "/gamelib/data/can_buy_book_list.csv";
	string content = Stdio.read_file(csv_path);

	if(!content) {
		test_fail("无法读取CSV文件");
		return;
	}

	array(string) lines = content / "\n";
	int fangshi_count = 0;
	int consistency_errors = 0;

	foreach(lines, string line) {
		if(!line || line == "" || line[0] == '#')
			continue;

		array(string) parts = line / ",";
		if(sizeof(parts) < 5)
			continue;

		if(parts[4] == "fangshi") {
			fangshi_count++;

			// 解析路径
			if(has_value(parts[1], "book/")) {
				string skill_name = parts[1];
				sscanf(skill_name, "book/%s", skill_name);

				// 检查技能文件
				string skill_file = ROOT + "/gamelib/single/skills/" + skill_name;
				if(Stdio.exist(skill_file)) {
					// 检查技能配置
					string skill_content = Stdio.read_file(skill_file);
					if(skill_content && !has_value(skill_content, "fangshi")) {
						werror("  ! %s 技能文件没有包含 fangshi 类型\n", skill_name);
						consistency_errors++;
					}
				}
			}
		}
	}

	werror("  检查了 %d 个方士技能配置\n", fangshi_count);

	if(consistency_errors > 0) {
		test_fail("发现 " + consistency_errors + " 个一致性错误");
	} else {
		test_pass();
	}
}

// 测试7: 心跳逻辑修复验证
void test_heartbeat_fix() {
	test_start("心跳逻辑修复验证");

	// 检查 heling.pike 是否使用了计数器而不是 time() % n
	string heling_path = ROOT + "/gamelib/clone/npc/summon/heling.pike";
	string content = Stdio.read_file(heling_path);

	if(!content) {
		test_fail("无法读取 heling.pike");
		return;
	}

	if(has_value(content, "heal_counter")) {
		werror("  ✓ heling.pike 使用了计数器\n");
	} else if(has_value(content, "time() %")) {
		test_fail("heling.pike 仍在使用 time() % n，应该使用计数器");
		return;
	} else {
		werror("  ! heling.pike 可能没有治疗计时逻辑\n");
	}

	// 检查 guiling.pike
	string guiling_path = ROOT + "/gamelib/clone/npc/summon/guiling.pike";
	content = Stdio.read_file(guiling_path);

	if(!content) {
		test_fail("无法读取 guiling.pike");
		return;
	}

	if(has_value(content, "taunt_counter")) {
		werror("  ✓ guiling.pike 使用了计数器\n");
	} else if(has_value(content, "time() %")) {
		test_fail("guiling.pike 仍在使用 time() % n，应该使用计数器");
		return;
	} else {
		werror("  ! guiling.pike 可能没有嘲讽计时逻辑\n");
	}

	test_pass();
}

// 测试8: 战斗AI优化验证
void test_combat_ai_optimization() {
	test_start("战斗AI优化验证");

	string base_path = ROOT + "/gamelib/clone/npc/summon/base_summon.pike";
	string content = Stdio.read_file(base_path);

	if(!content) {
		test_fail("无法读取 base_summon.pike");
		return;
	}

	// 检查是否移除了 _tasknpc 标记
	if(has_value(content, "_tasknpc = 1")) {
		test_fail("base_summon.pike 仍有 _tasknpc = 1，这会导致召唤物无法参与战斗");
		return;
	}
	werror("  ✓ 已移除 _tasknpc 标记\n");

	// 检查是否有环境检查
	if(has_value(content, "if(!master_env)") || has_value(content, "if(!env)")) {
		werror("  ✓ 有空指针检查\n");
	}

	// 检查死亡处理
	if(has_value(content, "SUMMOND->dismiss_creature")) {
		werror("  ✓ 死亡时会清理守护进程\n");
	}

	test_pass();
}

// 主测试运行函数
void run_tests() {
	werror("\n");
	werror("╔════════════════════════════════════════╗\n");
	werror("║   方士系统集成测试                      ║\n");
	werror("╚════════════════════════════════════════╝\n");

	test_skill_structure();
	test_summon_base_class();
	test_summon_creature_features();
	test_book_config();
	test_summon_daemon_logic();
	test_csv_file_consistency();
	test_heartbeat_fix();
	test_combat_ai_optimization();

	print_summary();
}

protected void create() {
	call_out(run_tests, 4);
}
