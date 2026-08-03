#!/usr/bin/env pike
/**
 * 剑仙断雷斩旧技能兼容与战斗视图回归测试。
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
	werror("\n[断雷斩 %d] %s\n",test_results["total"],name);
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

object create_player(string name,string profession)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "断雷斩测试角色";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId(profession);
	player->setup_player("human",profession);
	player->level = 80;
	player->set_att_by_level();
	player->set_base_hitte(100000);
	player->set_base_life(1000000000);
	player->flush_life();
	player->set_mofa(player->query_mofa_max());
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

void test_duanlei_cast_and_cooldown_view()
{
	test_start("旧版断雷斩真实施放、扣血与冷却页保持正常中文");
	object|zero player = 0;
	object|zero target = 0;
	object|zero weapon = 0;
	object|zero original_player = this_player();
	object room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object command =
		(object)(ROOT+"/lowlib/wapmud2/cmds/use_perform.pike");
	string first_page = "";
	string second_page = "";
	string error_desc = "";
	int mana_before = 0;
	int life_before = 0;
	int valid = 0;
	mixed err = catch {
		player = create_player("__testunit_jianxian_duanlei__","jianxian");
		target = create_player("__testunit_jianxian_duanlei_target__",
			"jianxian");
		player->move(room);
		target->move(room);
		target->set_base_dodge(-1000000);
		weapon = clone(ROOT+
			"/gamelib/clone/item/weapon/1taomujian/1taomujian");
		weapon->move(player);
		player->wield(weapon);
		player->skills["duanleizhan"] = ({1,0});
		mana_before = player->get_cur_mofa();
		life_before = target->get_cur_life();
		player->_fight(target);
		target->_fight(player);
		set_this_player(player);
		command->main("duanleizhan");
		first_page = (string)player->query_spliter()["text"];
		command->main("duanleizhan");
		second_page = (string)player->query_spliter()["text"];
		int hit = target->get_cur_life()<life_before;
		int valid_result = hit ?
			search(first_page,"点实际伤害")!=-1 :
			search(first_page,"未命中")!=-1;
		valid = player->get_cur_mofa()==mana_before-14 &&
			valid_result &&
			(int)player->f_skills["duanleizhan"]>1 &&
			first_page!="" && second_page!="" &&
			search(first_page,"断雷斩")!=-1 &&
			search(first_page,"�")==-1 &&
			search(second_page,"冷却时间")!=-1 &&
			search(second_page,"�")==-1;
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("断雷斩施放或页面编码错误: mana="+
			(player ? player->get_cur_mofa() : 0)+" life="+
			(target ? target->get_cur_life() : 0)+" first="+
			first_page+" second="+second_page+" "+error_desc);
	if(player && player->query_in_combat())
		player->_clean_fight();
	if(target && target->query_in_combat())
		target->_clean_fight();
	destroy_player(player);
	destroy_player(target);
}

int main()
{
	werror("\n========== 剑仙断雷斩回归测试 ==========\n");
	test_duanlei_cast_and_cooldown_view();
	werror("\n断雷斩测试完成: 总计 %d, 通过 %d, 失败 %d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
