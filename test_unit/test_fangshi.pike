#!/usr/bin/env pike
/**
 * ========================================================================
 * 方士系统单元测试
 * ========================================================================
 *
 * 测试方士职业的以下功能：
 * 1. 技能文件编译和加载
 * 2. 技能书文件编译和加载
 * 3. 召唤物文件编译和加载
 * 4. 召唤守护进程功能
 * 5. 技能配置完整性
 *
 * ========================================================================
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

// 测试结果统计
mapping(string:int) test_results = ([
	"total": 0,
	"passed": 0,
	"failed": 0,
]);

// 辅助函数：输出测试结果
void test_start(string test_name) {
	test_results["total"]++;
	werror("\n[方士测试 %d] %s\n", test_results["total"], test_name);
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
	werror("方士系统测试完成！\n");
	werror("总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"], test_results["passed"], test_results["failed"]);
	if(test_results["failed"] == 0) {
		werror("✓ 所有测试通过！\n");
	} else {
		werror("✗ 有 %d 个测试失败\n", test_results["failed"]);
	}
	werror("========================================\n");
}

// 测试1: 方士技能文件编译
void test_fangshi_skills_compile() {
	test_start("方士技能文件编译测试");

	array(string) skill_files = ({
		"lingdanshu", "lingren", "lingbaoshu", "linghundaji", "linghuti",
		"lingzhou", "lingyichu", "lingzhi", "lingji", "huling",
		"lingfeng", "lingqishu", "lingyong", "linghuchuan", "heling",
		"linghuoshao", "lingdun", "huanxiaoling", "lingxishu", "lingxuan",
		"lingqun", "lingliebao", "linglianpu", "lingshenhushu", "linghudun",
		"lingchuanxin", "lingxuanying", "lingzhihun", "lingbailei",
	});

	int passed = 0;
	foreach(skill_files, string skill_name) {
		string skill_path = ROOT + "/gamelib/single/skills/" + skill_name;
		mixed err = catch {
			program p = (program)skill_path;
			if(p) {
				passed++;
			}
		};
		if(err) {
			test_fail("技能 " + skill_name + " 编译失败: " + describe_error(err));
			return;
		}
	}

	if(passed == sizeof(skill_files)) {
		test_pass();
	} else {
		test_fail(sprintf("只有 %d/%d 个技能编译成功", passed, sizeof(skill_files)));
	}
}

// 测试2: 方士技能书文件编译
void test_fangshi_books_compile() {
	test_start("方士技能书文件编译测试");

	array(string) book_files = ({
		"lingdanshu", "lingren", "lingbaoshu", "linghundaji", "linghuti",
		"lingzhou", "lingyichu", "lingzhi", "lingji", "huling1", "huling2",
		"lingfeng", "lingqishu", "lingyong", "linghuchuan", "heling1", "heling2",
		"linghuoshao", "lingdun", "huanxiaoling", "lingxishu", "lingxuan",
		"lingqun", "lingliebao", "linglianpu", "lingshenhushu", "linghudun",
		"lingchuanxin", "lingxuanying", "lingzhihun", "lingbailei",
		"guiling1", "guiling2", "sanlingheyi1", "sanlingheyi2",
	});

	int passed = 0;
	foreach(book_files, string book_name) {
		string book_path = ROOT + "/gamelib/clone/item/book/" + book_name;
		if(!Stdio.exist(book_path)) {
			continue;
		}
		mixed err = catch {
			program p = (program)book_path;
			if(p) {
				passed++;
			}
		};
		if(err) {
			test_fail("技能书 " + book_name + " 编译失败: " + describe_error(err));
			return;
		}
	}

	werror("  (找到 %d 个技能书文件)\n", passed);
	test_pass();
}

// 测试3: 召唤物文件编译
void test_summon_creatures_compile() {
	test_start("召唤物文件编译测试");

	array(string) summon_files = ({
		"base_summon", "huling", "heling", "guiling",
	});

	int passed = 0;
	foreach(summon_files, string summon_name) {
		string summon_path = ROOT + "/gamelib/clone/npc/summon/" + summon_name;
		mixed err = catch {
			program p = (program)summon_path;
			if(p) {
				passed++;
			}
		};
		if(err) {
			test_fail("召唤物 " + summon_name + " 编译失败: " + describe_error(err));
			return;
		}
	}

	if(passed == sizeof(summon_files)) {
		test_pass();
	} else {
		test_fail(sprintf("只有 %d/%d 个召唤物编译成功", passed, sizeof(summon_files)));
	}
}

// 测试4: 召唤守护进程测试
void test_summon_daemon() {
	test_start("召唤守护进程测试");

	if(!SUMMOND) {
		test_fail("SUMMOND 守护进程不存在");
		return;
	}

	werror("  检查守护进程方法...\n");

	// 检查方法是否存在
	if(!functionp(SUMMOND->get_max_summons)) {
		test_fail("get_max_summons 方法不存在");
		return;
	}
	if(!functionp(SUMMOND->can_summon)) {
		test_fail("can_summon 方法不存在");
		return;
	}
	if(!functionp(SUMMOND->summon_creature)) {
		test_fail("summon_creature 方法不存在");
		return;
	}
	if(!functionp(SUMMOND->dismiss_creature)) {
		test_fail("dismiss_creature 方法不存在");
		return;
	}
	if(!functionp(SUMMOND->dismiss_all)) {
		test_fail("dismiss_all 方法不存在");
		return;
	}
	if(!functionp(SUMMOND->get_player_summons)) {
		test_fail("get_player_summons 方法不存在");
		return;
	}

	// 测试基本功能
	werror("  测试 get_max_summons(空)...\n");
	int max = SUMMOND->get_max_summons(0);
	if(max != 1) {
		test_fail("get_max_summons(0) 应该返回 1，返回了 " + max);
		return;
	}

	werror("  测试 can_summon(空)...\n");
	int can = SUMMOND->can_summon(0);
	if(can != 0) {
		test_fail("can_summon(0) 应该返回 0，返回了 " + can);
		return;
	}

	werror("  测试 get_current_summon_count(空)...\n");
	int count = SUMMOND->get_current_summon_count(0);
	if(count != 0) {
		test_fail("get_current_summon_count(0) 应该返回 0，返回了 " + count);
		return;
	}

	werror("  测试 get_player_summons(空)...\n");
	mapping summons = SUMMOND->get_player_summons(0);
	if(!mappingp(summons) || sizeof(summons) != 0) {
		test_fail("get_player_summons(0) 应该返回空映射");
		return;
	}

	test_pass();
}

// 测试5: 技能配置完整性检查
void test_skill_config_integrity() {
	test_start("技能配置完整性检查");

	string csv_path = ROOT + "/gamelib/data/can_buy_book_list.csv";
	if(!Stdio.exist(csv_path)) {
		test_fail("CSV 文件不存在: " + csv_path);
		return;
	}

	string content = Stdio.read_file(csv_path);
	if(!content) {
		test_fail("无法读取 CSV 文件");
		return;
	}

	// 解析CSV，查找方士技能
	array(string) lines = content / "\n";
	int fangshi_skill_count = 0;
	int missing_skill = 0;
	int missing_book = 0;

	foreach(lines, string line) {
		if(!line || line == "" || line[0] == '#')
			continue;

		array(string) parts = line / ",";
		if(sizeof(parts) < 5)
			continue;

		// 检查是否是方士技能
		if(sizeof(parts) >= 5 && parts[4] == "fangshi") {
			fangshi_skill_count++;

			// 提取技能名
			string book_path = parts[1];
			array(string) path_parts = book_path / "/";
			if(sizeof(path_parts) > 0) {
				string skill_name = path_parts[-1];

				// 检查技能文件是否存在
				string skill_file = ROOT + "/gamelib/single/skills/" + skill_name;
				if(!Stdio.exist(skill_file)) {
					werror("  ! 技能文件缺失: %s\n", skill_name);
					missing_skill++;
				}

				// 检查书籍文件是否存在
				string book_file = ROOT + "/gamelib/clone/item/book/" + skill_name;
				if(!Stdio.exist(book_file)) {
					werror("  ! 书籍文件缺失: %s\n", skill_name);
					missing_book++;
				}
			}
		}
	}

	werror("  找到 %d 个方士技能配置\n", fangshi_skill_count);

	if(missing_skill > 0 || missing_book > 0) {
		test_fail(sprintf("缺失 %d 个技能文件, %d 个书籍文件", missing_skill, missing_book));
	} else {
		test_pass();
	}
}

// 测试6: 召唤命令测试
void test_summon_command() {
	test_start("召唤命令测试");

	string summon_cmd_path = ROOT + "/gamelib/cmds/summon.pike";
	if(!Stdio.exist(summon_cmd_path)) {
		test_fail("summon.pike 文件不存在");
		return;
	}

	mixed err = catch {
		program p = (program)summon_cmd_path;
		if(p) {
			// 尝试读取文件内容检查关键功能
			string content = Stdio.read_file(summon_cmd_path);
			if(!content) {
				test_fail("无法读取 summon.pike 内容");
				return;
			}

			// 检查关键功能
			if(!has_value(content, "SUMMOND")) {
				test_fail("summon.pike 没有使用 SUMMOND");
				return;
			}
			if(!has_value(content, "huling")) {
				test_fail("summon.pike 没有处理 huling");
				return;
			}
			if(!has_value(content, "heling")) {
				test_fail("summon.pike 没有处理 heling");
				return;
			}
			if(!has_value(content, "guiling")) {
				test_fail("summon.pike 没有处理 guiling");
				return;
			}

			test_pass();
		} else {
			test_fail("summon.pike 编译失败");
		}
	};

	if(err) {
		test_fail("summon.pike 编译错误: " + describe_error(err));
	}
}

// 测试7: 方士NPC测试
void test_fangshi_npc() {
	test_start("方士传人NPC测试");

	string npc_path = ROOT + "/gamelib/clone/npc/fangshi_teacher.pike";
	if(!Stdio.exist(npc_path)) {
		test_fail("fangshi_teacher.pike 文件不存在");
		return;
	}

	mixed err = catch {
		program p = (program)npc_path;
		if(p) {
			test_pass();
		} else {
			test_fail("fangshi_teacher.pike 编译失败");
		}
	};

	if(err) {
		test_fail("fangshi_teacher.pike 编译错误: " + describe_error(err));
	}
}

// 测试8: 心跳逻辑修复验证
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

// 主测试运行函数 - 由 testunitd 调用
void run_tests() {
	werror("\n");
	werror("╔════════════════════════════════════════╗\n");
	werror("║   方士系统单元测试                      ║\n");
	werror("╚════════════════════════════════════════╝\n");

	test_fangshi_skills_compile();
	test_fangshi_books_compile();
	test_summon_creatures_compile();
	test_summon_daemon();
	test_skill_config_integrity();
	test_summon_command();
	test_fangshi_npc();
	test_heartbeat_fix();

	print_summary();
}

// 如果直接运行此文件（非守护进程模式），执行测试
int main() {
	run_tests();
	return 0;
}
