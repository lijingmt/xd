#!/usr/bin/env pike
/**
 * 新手自动穿装助手测试：
 * 建角接线 -> 七职业一级初始装备 -> 最优空位选择 ->
 * 现有装备保护 -> 穿戴限制 -> 双手武器冲突 -> 空背包。
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
	werror("\n[自动穿装助手 %d] %s\n",test_results["total"],name);
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

object create_runtime_player(string player_name,string race_name,
	string profession_name,int player_level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;

	player->set_name(player_name);
	player->name_cn = "穿装测试玩家";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race_name);
	player->set_profeId(profession_name);
	player->setup_player(race_name,profession_name);
	player->level = player_level;
	player->set_att_by_level();
	return player;
}

array(object) give_starter_equipment(object player)
{
	array(string) paths = ({
		"/gamelib/clone/item/weapon/1taomujian/1taomujian",
		"/gamelib/clone/item/armor/2caoxie/2caoxie",
		"/gamelib/clone/item/armor/2cubuchangku/2cubuchangku",
		"/gamelib/clone/item/armor/2cubuyi/2cubuyi",
	});
	array(object) items = ({});
	foreach(paths,string path){
		object item = clone(ROOT+path);
		if(item){
			item->move(player);
			items += ({item});
		}
	}
	return items;
}

void destroy_runtime_player(object|zero player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

object load_assistant()
{
	return (object)(ROOT+"/gamelib/cmds/auto_equip.pike");
}

void test_ui_and_creation_wiring()
{
	test_start("建角自动执行、背包入口与一级新手防具");
	string init_source = Stdio.read_file(ROOT+"/gamelib/d/init");
	string view_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/single/viewd.pike");
	string user_source = Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	array(string) armor_paths = ({
		"/gamelib/clone/item/armor/2caoxie/2caoxie",
		"/gamelib/clone/item/armor/2cubuchangku/2cubuchangku",
		"/gamelib/clone/item/armor/2cubuyi/2cubuyi",
	});
	int armor_valid = 1;

	foreach(armor_paths,string path){
		object armor = clone(ROOT+path);
		if(!armor || armor->query_item_canLevel() != 1)
			armor_valid = 0;
		if(armor)
			destruct(armor);
	}

	if(init_source && view_source && user_source && armor_valid &&
	   search(init_source,"me->command(\"auto_equip silent\")") != -1 &&
	   search(init_source,"新手穿衣助手已为你穿好初始装备") != -1 &&
	   search(view_source,"[一键穿装:auto_equip]") != -1 &&
	   search(user_source,
		"【新手助手】[新手引导:newbie_guide]|[自动穿装:auto_equip]") != -1)
		test_pass();
	else
		test_fail("建角、背包、新手快捷入口或装备等级没有完整接线");
}

void test_all_professions_starter_equipment()
{
	test_start("七个职业一级人物均可自动穿好四件初始装备");
	array(array(string)) professions = ({
		({"human","jianxian"}),
		({"human","yushi"}),
		({"human","zhuxian"}),
		({"monst","kuangyao"}),
		({"monst","wuyao"}),
		({"monst","yinggui"}),
		({"third","fangshi"}),
	});
	object assistant = load_assistant();
	int failed = 0;

	for(int i = 0;i < sizeof(professions);i++){
		object player = create_runtime_player(
			"__testunit_auto_prof_"+i+"__",
			professions[i][0],professions[i][1],1);
		array(object) items = give_starter_equipment(player);
		mapping result = assistant->auto_equip_player(player);
		int equipped = 0;
		foreach(items,object item){
			if(item->equiped)
				equipped++;
		}
		if(sizeof(items) != 4 ||
		   sizeof(result["equipped"]) != 4 ||
		   equipped != 4){
			failed++;
			werror("  ✗ %s 初始装备=%d，已穿=%d\n",
				professions[i][1],sizeof(items),equipped);
		}
		destroy_runtime_player(player);
	}

	if(failed == 0)
		test_pass();
	else
		test_fail(sprintf("%d 个职业未能穿好初始装备",failed));
}

void test_best_item_and_existing_protection()
{
	test_start("同槽选择更好装备并保护已经穿戴的装备");
	object assistant = load_assistant();
	object player = create_runtime_player(
		"__testunit_auto_best__","third","fangshi",20);
	object weak_shoes = clone(
		ROOT+"/gamelib/clone/item/armor/2caoxie/2caoxie");
	object strong_shoes = clone(
		ROOT+"/gamelib/clone/item/armor/2caoxie/2caoxie");
	object worn_cloth = clone(
		ROOT+"/gamelib/clone/item/armor/2cubuyi/2cubuyi");
	object replacement_cloth = clone(
		ROOT+"/gamelib/clone/item/armor/2cubuyi/2cubuyi");
	string error_desc = "";
	mapping result = ([]);

	mixed err = catch {
		weak_shoes->set_equip_defend(5);
		strong_shoes->set_equip_defend(50);
		replacement_cloth->set_equip_defend(500);
		weak_shoes->move(player);
		strong_shoes->move(player);
		worn_cloth->move(player);
		replacement_cloth->move(player);
		player->wear(worn_cloth);
		result = assistant->auto_equip_player(player);
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && strong_shoes->equiped && !weak_shoes->equiped &&
	   worn_cloth->equiped && !replacement_cloth->equiped &&
	   result["protected"] == 1 &&
	   result["rejected"]["occupied"] >= 1)
		test_pass();
	else
		test_fail("最优选择或空位保护失败: "+error_desc);

	destroy_runtime_player(player);
}

void test_equip_restrictions()
{
	test_start("等级、职业、属性、任务与禁穿限制逐项生效");
	object assistant = load_assistant();
	object player = create_runtime_player(
		"__testunit_auto_limits__","third","fangshi",1);
	object armor = clone(
		ROOT+"/gamelib/clone/item/armor/2caoxie/2caoxie");
	int failed = 0;
	string error_desc = "";

	mixed err = catch {
		armor->move(player);
		if(assistant->query_equip_reject_reason(player,armor) != "")
			failed++;

		armor->set_item_canLevel(99);
		if(assistant->query_equip_reject_reason(player,armor) != "level")
			failed++;
		armor->set_item_canLevel(1);

		armor->set_item_canEquip(0);
		if(assistant->query_equip_reject_reason(player,armor) != "disabled")
			failed++;
		armor->set_item_canEquip(1);

		armor->set_item_task(1);
		if(assistant->query_equip_reject_reason(player,armor) != "task_item")
			failed++;
		armor->set_item_task(0);

		armor->set_item_strLimit(9999);
		if(assistant->query_equip_reject_reason(player,armor) != "strength")
			failed++;
		armor->set_item_strLimit(0);

		armor->set_item_dexLimit(9999);
		if(assistant->query_equip_reject_reason(player,armor) != "dexterity")
			failed++;
		armor->set_item_dexLimit(0);

		armor->set_item_thinkLimit(9999);
		if(assistant->query_equip_reject_reason(player,armor) != "intelligence")
			failed++;
		armor->set_item_thinkLimit(0);

		player->set_profeId("__invalid_profession__");
		if(assistant->query_equip_reject_reason(player,armor) != "profession")
			failed++;
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && failed == 0)
		test_pass();
	else
		test_fail(sprintf("限制检查失败=%d: %s",failed,error_desc));

	destroy_runtime_player(player);
}

void test_two_hand_weapon_conflict()
{
	test_start("双手武器不会与主手、副手同时装备");
	object assistant = load_assistant();
	object player = create_runtime_player(
		"__testunit_auto_twohand__","third","fangshi",20);
	object double_weapon = clone(
		ROOT+"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	object main_weapon = clone(
		ROOT+"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	object other_weapon = clone(
		ROOT+"/gamelib/clone/item/weapon/1taomujian/1taomujian");
	string error_desc = "";

	mixed err = catch {
		double_weapon->set_item_type("double_weapon");
		double_weapon->set_item_kind("double_main_weapon");
		double_weapon->set_attack_power(100);
		double_weapon->set_attack_power_limit(100);
		main_weapon->set_item_type("single_weapon");
		main_weapon->set_item_kind("single_main_weapon");
		main_weapon->set_attack_power(10);
		main_weapon->set_attack_power_limit(10);
		other_weapon->set_item_type("single_weapon");
		other_weapon->set_item_kind("single_other_weapon");
		double_weapon->move(player);
		main_weapon->move(player);
		other_weapon->move(player);
		assistant->auto_equip_player(player);
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && double_weapon->equiped &&
	   !main_weapon->equiped && !other_weapon->equiped)
		test_pass();
	else
		test_fail("双手武器槽位冲突处理失败: "+error_desc);

	destroy_runtime_player(player);
}

void test_empty_inventory()
{
	test_start("空背包重复执行安全且结果提示完整");
	object assistant = load_assistant();
	object player = create_runtime_player(
		"__testunit_auto_empty__","third","fangshi",1);
	mapping result = assistant->auto_equip_player(player);
	string output = assistant->render_result(result);

	if(sizeof(result["equipped"]) == 0 &&
	   result["protected"] == 0 &&
	   search(output,"没有找到可以填补空位的装备") != -1 &&
	   search(output,"只补空位") != -1)
		test_pass();
	else
		test_fail("空背包结果或帮助提示不正确");

	destroy_runtime_player(player);
}

void print_summary()
{
	werror("\n========================================\n");
	werror("自动穿装助手测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	werror("========================================\n");
}

int main()
{
	test_ui_and_creation_wiring();
	test_all_professions_starter_equipment();
	test_best_item_and_existing_protection();
	test_equip_restrictions();
	test_two_hand_weapon_conflict();
	test_empty_inventory();
	print_summary();
	return test_results["failed"];
}
