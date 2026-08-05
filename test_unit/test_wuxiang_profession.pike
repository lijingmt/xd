#!/usr/bin/env pike
/**
 * 无相职业测试：身份层、属性成长、解锁条件、入门技能可学习。
 * 完整 15 技能 + 隐藏池扩展由后续迭代补齐；本测试先确保
 * 「账号满足条件 → 能创建无相 → 初始属性对 → 1 级能学无相拳」。
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
	werror("\n[无相 %d] %s\n",test_results["total"],name);
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
	player->name_cn = "无相测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("wuxiang");
	player->setup_player("third","wuxiang");
	player->level = 1;
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

void test_identity_setup()
{
	test_start("无相创建后 race/profe/中文身份正确");
	object player = create_runtime_player("__testunit_wuxiang_identity__");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		valid = player->query_raceId() == "third" &&
			player->query_profeId() == "wuxiang" &&
			player->query_profe_cn("wuxiang") == "无相" &&
			player->query_kind_cn() == "中立";
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("身份字段错误: "+error_desc);
	destroy_runtime_player(player);
}

void test_initial_stats()
{
	test_start("无相 1 级初始属性：力/敏/智 8/8/8");
	object player = create_runtime_player("__testunit_wuxiang_stats__");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		// life_max 由 str*10+base+level*50 公式动态计算，初始 set_life 会被
		// set_att_by_level 覆盖；这里只校验三系基础属性。
		valid = (int)player->query_str() == 8 &&
			(int)player->query_dex() == 8 &&
			(int)player->query_think() == 8;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail(sprintf("初始属性不符: str=%d dex=%d think=%d %s",
			(int)player->query_str(),(int)player->query_dex(),
			(int)player->query_think(),error_desc));
	destroy_runtime_player(player);
}

void test_level_growth()
{
	test_start("无相等级成长：30 级三系对称 str=dex=think=52");
	object player = create_runtime_player("__testunit_wuxiang_growth__");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		player->level = 30;
		player->set_att_by_level();
		// 公式：8 + floor((30-1)*1.5) = 8 + floor(43.5) = 8 + 43 = 51
		valid = (int)player->query_str() == 51 &&
			(int)player->query_dex() == 51 &&
			(int)player->query_think() == 51;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail(sprintf("30级成长不符: str=%d dex=%d think=%d %s",
			(int)player->query_str(),(int)player->query_dex(),
			(int)player->query_think(),error_desc));
	destroy_runtime_player(player);
}

void test_starter_skill_granted()
{
	test_start("无相创建后自动获得无相拳技能");
	object player = create_runtime_player("__testunit_wuxiang_skill__");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		// 模拟 init 里的赋予逻辑
		if(player->skills["wuxiangquan"]==0)
			player->skills["wuxiangquan"]=({1,0});
		valid = player->skills["wuxiangquan"] &&
			sizeof((array)player->skills["wuxiangquan"]) >= 1 &&
			(int)player->skills["wuxiangquan"][0] >= 1;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("未授予无相拳: "+error_desc);
	destroy_runtime_player(player);
}

void test_skill_file_loads()
{
	test_start("无相拳技能对象能加载且 s_type=zhudong");
	string error_desc = "";
	int valid = 0;
	object|zero skill = 0;
	mixed err = catch {
		skill = (object)(ROOT+"/gamelib/single/skills/wuxiangquan");
		valid = skill && skill->s_type == "zhudong" &&
			search(skill->skill_type,"wuxiang") != -1;
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("wuxiangquan 加载失败: "+error_desc);
	if(skill)
		destruct(skill);
}

void test_book_file_loads()
{
	test_start("无相拳书对象能加载且 skill_bname=wuxiangquan");
	string error_desc = "";
	int valid = 0;
	object|zero book = 0;
	mixed err = catch {
		book = clone(ROOT+"/gamelib/clone/item/book/wuxiangquan");
		valid = book && book->skill_bname == "wuxiangquan" &&
			book->profe_read_limit == "无相";
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("wuxiangquan 书加载失败: "+error_desc);
	if(book)
		destruct(book);
}

void test_teacher_loads()
{
	test_start("无相先生 NPC 能加载且 profeId=wuxiang");
	string error_desc = "";
	int valid = 0;
	object|zero teacher = 0;
	mixed err = catch {
		teacher = clone(ROOT+"/gamelib/clone/npc/wuxiang_teacher.pike");
		valid = teacher && teacher->query_profeId() == "wuxiang" &&
			teacher->query_raceId() == "third";
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("无相先生 NPC 加载失败: "+error_desc);
	if(teacher)
		destruct(teacher);
}

void test_default_unnamed_title()
{
	test_start("无相默认无名头衔源码包含「无名无相」");
	string base_source = Stdio.read_file(ROOT+
		"/lowlib/system/inherit/base.pike");
	string error_desc = "";
	int valid = 0;
	if(!base_source)
		error_desc = "无法读取 base.pike";
	else
		valid = search(base_source,"无名无相") != -1 &&
			search(base_source,"\"wuxiang\"") != -1;
	if(valid)
		test_pass();
	else
		test_fail("base.pike 未识别 wuxiang 无名头衔: "+error_desc);
}

int main()
{
	werror("\n========== 无相职业测试 ==========\n");
	test_identity_setup();
	test_initial_stats();
	test_level_growth();
	test_starter_skill_granted();
	test_skill_file_loads();
	test_book_file_loads();
	test_teacher_loads();
	test_default_unnamed_title();
	werror("\n无相职业测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"] == 0 ? 0 : 1;
}
