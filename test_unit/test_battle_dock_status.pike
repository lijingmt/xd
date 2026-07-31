#!/usr/bin/env pike
/**
 * Vue 战斗小窗状态链路回归测试。
 *
 * 覆盖真实交战目标、敌人完整数据、玩家法力字段，以及开战瞬间
 * “交战中（目标名）”不能出现空括号。
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
	werror("\n[战斗小窗 %d] %s\n",test_results["total"],name);
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

object create_runtime_player()
{
	object player = clone(GAMELIB_USER);
	player->set_name("__testunit_battle_dock__");
	player->name_cn = "战斗小窗测试方士";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->level = 10;
	player->set_att_by_level();
	return player;
}

void destroy_runtime_object(object|zero ob)
{
	if(ob)
		destruct(ob);
}

void test_real_enemy_and_status()
{
	test_start("真实战斗立即返回怪物名且状态括号不为空");
	object|zero player = 0;
	object|zero enemy = 0;
	object|zero room = 0;
	object|zero original_player = this_player();
	object|zero api_enemy = 0;
	mapping enemy_state = ([]);
	mapping player_state = ([]);
	string combat_status = "";
	string error_desc = "";
	int started = 0;
	mixed err = catch {
		player = create_runtime_player();
		room = clone(ROOT+"/gamelib/d/jinaodao/huangshayuanye");
		foreach(all_inventory(room),object item)
			destruct(item);
		enemy = clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
		player->move(room);
		enemy->move(room);
		set_this_player(player);
		started = player->kill(enemy,0);
		api_enemy = HTTP_APID->query_battle_enemy(player);
		enemy_state = HTTP_APID->query_battle_enemy_state(api_enemy);
		player_state = HTTP_APID->query_player_state(player);
		combat_status = player->query_status();
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err){
		error_desc = describe_error(err);
		werror("[战斗小窗] 真实战斗回溯: %s\n",describe_backtrace(err));
	}

	if(!err && started==1 && api_enemy==enemy &&
	   enemy_state["name_cn"]=="游荡恶狼" &&
	   enemy_state["level"]==9 &&
	   enemy_state["hp"]>0 && enemy_state["hp_max"]>0 &&
	   search(indices(enemy_state),"attack")!=-1 &&
	   search(indices(enemy_state),"attack_low")!=-1 &&
	   search(indices(enemy_state),"attack_high")!=-1 &&
	   search(indices(enemy_state),"defend")!=-1 &&
	   enemy_state["attack_low"]>=0 &&
	   enemy_state["attack_high"]>=enemy_state["attack_low"] &&
	   enemy_state["attack"]==enemy_state["attack_high"] &&
	   enemy_state["defend"]>=0 &&
	   search(indices(player_state),"mana")!=-1 &&
	   search(indices(player_state),"mana_max")!=-1 &&
	   player_state["mana"]>=0 && player_state["mana_max"]>0 &&
	   search(combat_status,"交战中（游荡恶狼）")!=-1 &&
	   search(combat_status,"交战中（）")==-1)
		test_pass();
	else
		test_fail("敌人解析、法力字段或交战标题错误: "+error_desc+
			" status="+combat_status+" enemy="+sprintf("%O",enemy_state));

	if(player)
		player->_clean_fight();
	if(enemy && enemy->query_in_combat())
		enemy->_clean_fight();
	destroy_runtime_object(enemy);
	destroy_runtime_object(player);
	if(room){
		foreach(all_inventory(room),object item)
			destruct(item);
		destruct(room);
	}
}

void test_empty_enemy_state()
{
	test_start("无交战目标时返回空状态而不抛异常");
	mapping state = ([]);
	string error_desc = "";
	mixed err = catch {
		state = HTTP_APID->query_battle_enemy_state(0);
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && mappingp(state) && sizeof(state)==0)
		test_pass();
	else
		test_fail("空目标处理错误: "+error_desc);
}

int main()
{
	werror("\n========================================\n");
	werror("Vue 战斗小窗状态链路回归测试\n");
	werror("========================================\n");

	test_real_enemy_and_status();
	test_empty_enemy_state();

	werror("\n战斗小窗测试完成: 总计 %d, 通过 %d, 失败 %d\n",
		test_results["total"],
		test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
