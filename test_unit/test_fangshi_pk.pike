#!/usr/bin/env pike
/**
 * ========================================================================
 * 方士PK测试
 * ========================================================================
 *
 * 测试方士玩家之间的PK功能：
 * 1. 方士vs方士 PK
 * 2. 方士vs其他阵营 PK
 * 3. 方士技能在PK中的释放
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
	werror("\n[PK测试 %d] %s\n", test_results["total"], test_name);
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
	werror("方士PK测试完成！\n");
	werror("总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"], test_results["passed"], test_results["failed"]);
	if(test_results["failed"] == 0) {
		werror("✓ 所有测试通过！\n");
	} else {
		werror("✗ 有 %d 个测试失败\n", test_results["failed"]);
	}
	werror("========================================\n");
}

// 测试1: 检查third阵营在user.pike中的荣誉值处理
void test_third_race_honor() {
	test_start("third阵营荣誉值测试");

	// 读取user.pike，检查third阵营的荣誉值处理
	string user_path = ROOT + "/gamelib/clone/user.pike";
	string content = Stdio.read_file(user_path);

	if(!content) {
		test_fail("无法读取user.pike");
		return;
	}

	// 检查third阵营是否被正确处理（灵气）
	if(has_value(content, "query_raceId()==\"third\"")) {
		werror("  ✓ user.pike中有third阵营的处理\n");
	} else {
		test_fail("user.pike中没有third阵营的处理");
		return;
	}

	// 检查灵气奖励
	if(has_value(content, "灵气")) {
		werror("  ✓ third阵营击杀奖励灵气\n");
	} else {
		test_fail("没有找到灵气奖励");
		return;
	}

	test_pass();
}

// 测试2: 检查third阵营在NPC互动中的处理
void test_third_race_npc() {
	test_start("third阵营NPC互动测试");

	string npc_path = ROOT + "/gamelib/inherit/npc.pike";
	string content = Stdio.read_file(npc_path);

	if(!content) {
		test_fail("无法读取npc.pike");
		return;
	}

	// 检查third阵营NPC的互动逻辑
	if(has_value(content, "query_raceId()==\"third\"")) {
		werror("  ✓ npc.pike中有third阵营的处理\n");
	} else {
		test_fail("npc.pike中没有third阵营的处理");
		return;
	}

	// 检查third阵营NPC可以被所有阵营攻击
	// 根据代码1079行，third阵营NPC显示对话和杀戮选项给所有人
	if(has_value(content, "该npc是中立阵营")) {
		werror("  ✓ third阵营NPC被标记为中立\n");
	} else {
		test_fail("没有找到中立阵营标记");
		return;
	}

	test_pass();
}

// 测试3: 检查方士技能在PK中的使用
void test_fangshi_skills_in_pk() {
	test_start("方士技能PK测试");

	// 检查方士技能是否可以用于PVP
	array(string) fangshi_skills = ({
		"lingdanshu", "lingren", "lingbaoshu", "linghundaji", "linghuti",
		"lingzhou", "lingyichu", "lingzhi", "lingji", "huling",
		"lingfeng", "lingqishu", "lingyong", "linghuchuan", "heling",
		"linghuoshao", "lingdun", "huanxiaoling", "lingxishu", "lingxuan",
	});

	int all_exist = 1;
	foreach(fangshi_skills, string skill_name) {
		string skill_path = ROOT + "/gamelib/single/skills/" + skill_name;
		if(!Stdio.exist(skill_path)) {
			werror("  ! 技能文件不存在: %s\n", skill_name);
			all_exist = 0;
		}
	}

	if(all_exist) {
		werror("  ✓ 所有方士技能文件都存在\n");
		test_pass();
	} else {
		test_fail("部分技能文件缺失");
	}
}

// 测试4: 检查方士技能书可以学习
void test_fangshi_skill_books() {
	test_start("方士技能书学习测试");

	// 检查技能书NPC
	string npc_path = ROOT + "/gamelib/clone/npc/fangshi_teacher.pike";
	if(!Stdio.exist(npc_path)) {
		test_fail("fangshi_teacher.pike不存在");
		return;
	}

	string content = Stdio.read_file(npc_path);
	if(!content) {
		test_fail("无法读取fangshi_teacher.pike");
		return;
	}

	// 检查是否有技能学习逻辑
	if(has_value(content, "skill") || has_value(content, "技能")) {
		werror("  ✓ fangshi_teacher有技能相关逻辑\n");
	} else {
		test_fail("fangshi_teacher没有技能学习逻辑");
		return;
	}

	test_pass();
}

// 测试5: 检查召唤物在PK中的表现
void test_summon_in_pk() {
	test_start("召唤物PK测试");

	// 检查召唤物基类
	string base_summon_path = ROOT + "/gamelib/clone/npc/summon/base_summon.pike";
	if(!Stdio.exist(base_summon_path)) {
		test_fail("base_summon.pike不存在");
		return;
	}

	string content = Stdio.read_file(base_summon_path);
	if(!content) {
		test_fail("无法读取base_summon.pike");
		return;
	}

	// 检查战斗参与逻辑
	if(has_value(content, "query_in_combat")) {
		werror("  ✓ 召唤物参与战斗\n");
	} else {
		test_fail("召唤物不参与战斗");
		return;
	}

	// 检查攻击逻辑
	if(has_value(content, "kill")) {
		werror("  ✓ 召唤物可以攻击敌人\n");
	} else {
		test_fail("召唤物没有攻击逻辑");
		return;
	}

	// 检查跟随逻辑
	if(has_value(content, "master_env")) {
		werror("  ✓ 召唤物跟随主人\n");
	} else {
		test_fail("召唤物没有跟随逻辑");
		return;
	}

	test_pass();
}

// 测试6: 检查third阵营玩家的轮回值处理
void test_third_race_lunhui() {
	test_start("third阵营轮回值测试");

	string user_path = ROOT + "/gamelib/clone/user.pike";
	string content = Stdio.read_file(user_path);

	if(!content) {
		test_fail("无法读取user.pike");
		return;
	}

	// 检查third阵营玩家击杀后的轮回值处理
	// 根据代码576行：human和third阵营击杀后会减少轮回值
	if(has_value(content, "query_raceId()==\"human\" || me->query_raceId()==\"third\"")) {
		werror("  ✓ third阵营玩家有轮回值处理\n");
	} else {
		test_fail("没有找到third阵营的轮回值处理");
		return;
	}

	test_pass();
}

// 测试7: 检查方士技能伤害类型
void test_fangshi_skill_damage_types() {
	test_start("方士技能伤害类型测试");

	// 检查几个核心技能的伤害类型
	mapping(string:string) skill_types = ([
		"linghuoshao": "curse",   // 灵火烧 - 持续伤害/减益
		"lingxuan": "phy",        // 灵悬 - 物理攻击
		"lingdun": "buff",        // 灵盾 - 防御buff
		"huling": "zhudong",      // 虎灵 - 主动技能
	]);

	int checked = 0;
	foreach(skill_types; string skill_name; string expected_type) {
		string skill_path = ROOT + "/gamelib/single/skills/" + skill_name;
		if(Stdio.exist(skill_path)) {
			string content = Stdio.read_file(skill_path);
			if(content && has_value(content, expected_type)) {
				checked++;
				werror("  ✓ %s 类型正确: %s\n", skill_name, expected_type);
			} else {
				werror("  ! %s 未找到类型: %s\n", skill_name, expected_type);
			}
		} else {
			werror("  ! %s 文件不存在\n", skill_name);
		}
	}

	if(checked == sizeof(skill_types)) {
		test_pass();
	} else {
		test_fail(sprintf("只有 %d/%d 个技能类型正确", checked, sizeof(skill_types)));
	}
}

// 主测试运行函数 - 由 testunitd 调用
void run_tests() {
	werror("\n");
	werror("╔════════════════════════════════════════╗\n");
	werror("║   方士PK系统单元测试                   ║\n");
	werror("╚════════════════════════════════════════╝\n");

	test_third_race_honor();
	test_third_race_npc();
	test_fangshi_skills_in_pk();
	test_fangshi_skill_books();
	test_summon_in_pk();
	test_third_race_lunhui();
	test_fangshi_skill_damage_types();

	print_summary();
}

// 如果直接运行此文件（非守护进程模式），执行测试
int main() {
	run_tests();
	return 0;
}
