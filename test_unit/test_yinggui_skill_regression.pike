#!/usr/bin/env pike
/**
 * 影鬼脱战技能、冷却显示与战斗视图回归测试。
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
	werror("\n[影鬼技能 %d] %s\n",test_results["total"],name);
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

object create_player(string name)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "影鬼技能测试角色";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("monst");
	player->set_profeId("yinggui");
	player->setup_player("monst","yinggui");
	player->level = 80;
	player->set_att_by_level();
	player->set_base_life(1000000);
	player->flush_life();
	player->set_mofa(player->query_mofa_max());
	return player;
}

void destroy_player(object|zero player)
{
	if(player)
		destruct(player);
}

void test_jinchan_escape_and_view_state()
{
	test_start("金蝉魅影脱战生效并返回非空场景视图");
	object|zero player = 0;
	object|zero target = 0;
	object|zero room = 0;
	object|zero original_player = this_player();
	object command = (object)(ROOT+
		"/lowlib/wapmud2/cmds/use_perform.pike");
	string skill_view = "";
	string detail_view = "";
	string page_text = "";
	string second_page_text = "";
	string error_desc = "";
	mapping page_state = ([]);
	int mana_before = 0;
	int cooldown_after = 0;
	int valid = 0;
	mixed err = catch {
		player = create_player("__testunit_yinggui_jinchan__");
		target = create_player("__testunit_yinggui_jinchan_target__");
		room = clone(ROOT+
			"/gamelib/d/congxianzhen/congxianzhenguangchang");
		foreach(all_inventory(room),object old_item)
			destruct(old_item);
		player->move(room);
		target->move(room);
		player->skills["jinchanmeiying"] = ({1,0});
		player->f_skills["fuji"] = 30;
		player->set_mofa(player->query_mofa_max());
		mana_before = player->get_cur_mofa();
		player->_fight(target);
		target->_fight(player);
		set_this_player(player);
		command->main("jinchanmeiying");
		cooldown_after = (int)player->f_skills["jinchanmeiying"];
		skill_view = player->view_skills();
		detail_view = player->view_performs("jinchanmeiying");
		page_state = player->query_spliter();
		page_text = (string)page_state["text"];
		command->main("jinchanmeiying");
		page_state = player->query_spliter();
		second_page_text = (string)page_state["text"];
		valid = !player->in_combat && player->hind==1 &&
			player->get_cur_mofa()==mana_before-500 &&
			cooldown_after>290 && cooldown_after<=301 &&
			!player->f_skills["fuji"] &&
			!target->if_in_targets(player) &&
			page_text!="" && second_page_text!="" &&
			search(page_text,"察看战况")==-1 &&
			search(second_page_text,"察看战况")==-1 &&
			search(skill_view,"金蝉魅影")!=-1 &&
			search(skill_view,"(5m)")!=-1 &&
			search(skill_view,"(6m)")==-1 &&
			search(detail_view,"当前冷却：(5m)")!=-1;
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
		test_fail("脱战、冷却或视图状态错误: cold="+cooldown_after+
			" page="+sizeof(page_text)+" second="+
			sizeof(second_page_text)+" "+error_desc);
	if(player && player->query_in_combat())
		player->_clean_fight();
	if(target && target->query_in_combat())
		target->_clean_fight();
	destroy_player(player);
	destroy_player(target);
	if(room)
		destruct(room);
}

void test_jinchan_second_stage_effect()
{
	test_start("二级金蝉魅影脱战后保留增伤与自身冷却");
	object|zero player = 0;
	object|zero target = 0;
	object room =
		(object)(ROOT+"/gamelib/d/congxianzhen/congxianzhenguangchang");
	string error_desc = "";
	int valid = 0;
	mixed err = catch {
		player = create_player("__testunit_yinggui_jinchan2__");
		target = create_player("__testunit_yinggui_jinchan2_target__");
		player->move(room);
		target->move(room);
		player->skills["jinchanmeiying2"] = ({1,0});
		player->f_skills["fuji"] = 30;
		player->_fight(target);
		target->_fight(player);
		player->perform("jinchanmeiying2",1);
		valid = !player->in_combat && player->hind==1 &&
			(int)player->f_skills["jinchanmeiying2"]>290 &&
			!player->f_skills["fuji"] &&
			player->query_buff("spec_attack_buff",0)==
				"jinchanmeiying2" &&
			player->query_buff("spec_attack_buff",1)==5 &&
			player->query_buff("spec_attack_buff",2)==25;
	};
	if(err)
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
	if(!err && valid)
		test_pass();
	else
		test_fail("二级影遁效果或冷却错误: "+error_desc);
	if(player && player->query_in_combat())
		player->_clean_fight();
	if(target && target->query_in_combat())
		target->_clean_fight();
	destroy_player(player);
	destroy_player(target);
}

int main()
{
	werror("\n========== 影鬼技能回归测试 ==========\n");
	test_jinchan_escape_and_view_state();
	test_jinchan_second_stage_effect();
	werror("\n影鬼技能测试完成: 总计 %d, 通过 %d, 失败 %d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
