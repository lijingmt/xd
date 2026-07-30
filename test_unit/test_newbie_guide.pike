#!/usr/bin/env pike
/**
 * 新手引导测试：
 * 真实装备状态、方士技能成长提示、治疗说明与入口接线。
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
	werror("\n[新手引导 %d] %s\n",test_results["total"],name);
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

object create_player(string name,int level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "引导测试方士";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->level = level;
	player->set_att_by_level();
	player->skills["lingdanshu"] = ({1,0});
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

void test_real_equipment_state()
{
	test_start("引导根据真实穿戴状态判断，不靠点击完成");
	object player = create_player("__testunit_guide_equip__",1);
	object guide = (object)(ROOT+"/gamelib/cmds/newbie_guide.pike");
	object assistant = (object)(ROOT+"/gamelib/cmds/auto_equip.pike");
	array(string) paths = ({
		"/gamelib/clone/item/weapon/1taomujian/1taomujian",
		"/gamelib/clone/item/armor/2caoxie/2caoxie",
		"/gamelib/clone/item/armor/2cubuchangku/2cubuchangku",
		"/gamelib/clone/item/armor/2cubuyi/2cubuyi",
	});
	string before = guide->render_guide(player);
	foreach(paths,string path){
		object item = clone(ROOT+path);
		if(item)
			item->move(player);
	}
	assistant->auto_equip_player(player);
	string after = guide->render_guide(player);

	if(guide->query_equipped_count(player)==4 &&
	   search(before,"还有基础空位")!=-1 &&
	   search(after,"基础武器和防具已经穿好")!=-1 &&
	   search(after,"只补空位")!=-1)
		test_pass();
	else
		test_fail("引导没有随真实装备状态更新");
	destroy_player(player);
}

void test_fangshi_level_guidance()
{
	test_start("方士1级、8级、24级技能成长提示完整");
	object guide = (object)(ROOT+"/gamelib/cmds/newbie_guide.pike");
	object level_one = create_player("__testunit_guide_l1__",1);
	object level_eight = create_player("__testunit_guide_l8__",8);
	object level_twenty_four =
		create_player("__testunit_guide_l24__",24);
	string one = guide->render_guide(level_one);
	string eight;
	string twenty_four;

	level_eight->skills["lingzhi"] = ({1,0});
	level_twenty_four->skills["lingzhi"] = ({1,0});
	level_twenty_four->skills["linglianpu"] = ({1,0});
	eight = guide->render_guide(level_eight);
	twenty_four = guide->render_guide(level_twenty_four);

	if(search(one,"8级可学习“灵治”")!=-1 &&
	   search(one,"24级解锁“灵莲铺”")!=-1 &&
	   search(eight,"“灵治”治疗自己")!=-1 &&
	   search(twenty_four,"没组队时只治疗自己")!=-1 &&
	   search(twenty_four,"[召唤灵兽:summon]")!=-1)
		test_pass();
	else
		test_fail("等级解锁、单体治疗或组队治疗说明缺失");

	destroy_player(level_one);
	destroy_player(level_eight);
	destroy_player(level_twenty_four);
}

void test_common_growth_and_home_links()
{
	test_start("打怪、掉落、任务、队伍、聊天与家园说明齐全");
	object guide = (object)(ROOT+"/gamelib/cmds/newbie_guide.pike");
	object player = create_player("__testunit_guide_common__",10);
	string output = guide->render_guide(player);
	player->set_home_path("xd/test/test/lei/001");
	string home_output = guide->render_guide(player);

	if(search(output,"怪物会提供经验、金钱和随机装备")!=-1 &&
	   search(output,"[查看地图:map_display]")!=-1 &&
	   search(output,"[查看任务:mytasks]")!=-1 &&
	   search(output,"[队伍:my_term]")!=-1 &&
	   search(output,"[聊天:chatroom_list]")!=-1 &&
	   search(output,"家园系统不限制职业")!=-1 &&
	   search(home_output,
		"[返回家园:home_return xd/test/test/lei/001]")!=-1)
		test_pass();
	else
		test_fail("通用成长或家园入口不完整");
	destroy_player(player);
}

void test_fangshi_advanced_milestones()
{
	test_start("方士30至75级召唤、高级书、隐藏书与职业任务提示完整");
	object guide = (object)(ROOT+"/gamelib/cmds/newbie_guide.pike");
	object level_thirty = create_player("__testunit_guide_l30__",30);
	object level_fifty = create_player("__testunit_guide_l50__",50);
	object level_sixty = create_player("__testunit_guide_l60__",60);
	object level_sixty_five = create_player("__testunit_guide_l65__",65);
	object level_seventy = create_player("__testunit_guide_l70__",70);
	object level_seventy_five = create_player("__testunit_guide_l75__",75);
	string thirty = guide->query_fangshi_growth_guide(level_thirty);
	string fifty;
	string sixty;
	string sixty_five;
	string seventy;
	string seventy_five;

	level_fifty->skills["sanlingheyi"] = ({1,0});
	fifty = guide->query_fangshi_growth_guide(level_fifty);
	sixty = guide->query_fangshi_growth_guide(level_sixty);
	sixty_five = guide->query_fangshi_growth_guide(level_sixty_five);
	seventy = guide->query_fangshi_growth_guide(level_seventy);
	seventy_five = guide->query_fangshi_growth_guide(level_seventy_five);

	if(search(thirty,"30级起可同时保留2只灵兽")!=-1 &&
	   search(fifty,"已掌握“三灵合一”")!=-1 &&
	   search(sixty,"每天为每个职业独立轮换2种")!=-1 &&
	   search(sixty,"[高级技能书:yushi_buy_hlbook_list]")!=-1 &&
	   search(sixty_five,"65级进阶书会替换旧技能")!=-1 &&
	   search(seventy,"实际等级70以上怪物")!=-1 &&
	   search(seventy,"不会出现在任何商店")!=-1 &&
	   search(seventy_five,"75级秘传可强化")!=-1 &&
	   search(seventy_five,"53级四段职业传承")!=-1)
		test_pass();
	else
		test_fail("30/50/60/65/70/75级关键路线仍有缺项");

	destroy_player(level_thirty);
	destroy_player(level_fifty);
	destroy_player(level_sixty);
	destroy_player(level_sixty_five);
	destroy_player(level_seventy);
	destroy_player(level_seventy_five);
}

void test_creation_and_ui_wiring()
{
	test_start("建角提示与新手快捷入口已经接线");
	string init_source = Stdio.read_file(ROOT+"/gamelib/d/init");
	string user_source = Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	program|zero guide_program = 0;
	mixed err = catch {
		guide_program =
			(program)(ROOT+"/gamelib/cmds/newbie_guide.pike");
	};

	if(!err && guide_program && init_source && user_source &&
	   search(init_source,
		"[查看新手引导:newbie_guide]")!=-1 &&
	   search(user_source,
		"[新手引导:newbie_guide]|[自动穿装:auto_equip]")!=-1)
		test_pass();
	else
		test_fail("建角或常驻新手入口没有完整接线");
}

void print_summary()
{
	werror("\n========================================\n");
	werror("新手引导测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	werror("========================================\n");
}

int main()
{
	test_real_equipment_state();
	test_fangshi_level_guidance();
	test_common_growth_and_home_links();
	test_fangshi_advanced_milestones();
	test_creation_and_ui_wiring();
	print_summary();
	return test_results["failed"];
}
