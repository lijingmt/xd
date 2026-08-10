#!/usr/bin/env pike
/** 动态怪 100-122 级属性与生命平滑衔接回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	test_results["total"]++;
	if(valid){
		test_results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		test_results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

object make_dynamic_npc(int level,int boss,int meritocrat)
{
	object npc = clone(ROOT+"/gamelib/clone/npc/kunlunshan/qinyuan1");
	if(!npc)
		return 0;
	npc->_npcLevel = level;
	npc->_boss = boss;
	npc->_meritocrat = meritocrat;
	return npc;
}

void test_scale_boundaries()
{
	object npc = make_dynamic_npc(100,0,0);
	array(int) defenses = ({0,1,100,1000,10000,100000});
	int valid = npc!=0;
	string reason = "";
	if(npc){
		for(int defense_index=0;
		    defense_index<sizeof(defenses);defense_index++){
			int defense = defenses[defense_index];
			int target = (int)pow(defense,0.3);
			int previous = npc->query_dynamic_npc_defense_scale(98,defense);
			if(target<1)
				target = 1;
			if(previous!=1000)
				valid = 0;
			for(int level=99;level<=122;level++){
				int scale = npc->query_dynamic_npc_defense_scale(
					level,defense);
				if(level<=100 && scale!=1000)
					valid = 0;
				if(level>=120 && scale!=target*1000)
					valid = 0;
				if(scale<previous)
					valid = 0;
				previous = scale;
			}
		}
	}
	if(!valid)
		reason = "100级端点、120级历史倍率或单调性不成立";
	check("多防御样本在100-120级平滑且端点不变",valid,reason);
	if(npc)
		destruct(npc);
}

void test_no_level_101_cliff()
{
	object npc = make_dynamic_npc(100,0,0);
	int defense = 100000;
	int scale_100 = 0;
	int scale_101 = 0;
	int scale_120 = 0;
	int target_multiplier = (int)pow(defense,0.3);
	int target = target_multiplier*1000;
	int expected_101 = (int)(pow((float)target_multiplier,0.05)*1000);
	if(npc){
		scale_100 = npc->query_dynamic_npc_defense_scale(100,defense);
		scale_101 = npc->query_dynamic_npc_defense_scale(101,defense);
		scale_120 = npc->query_dynamic_npc_defense_scale(120,defense);
	}
	check("101级按倍率几何平滑且不超过1.2倍",
		npc && scale_100==1000 &&
		scale_101==expected_101 && scale_101<1200 &&
		scale_120==target,
		sprintf("scale100=%d scale101=%d expected=%d scale120=%d target=%d",
			scale_100,scale_101,expected_101,scale_120,target));
	if(npc)
		destruct(npc);
}

void test_life_scale_transition()
{
	object npc = make_dynamic_npc(100,0,0);
	array(int) defenses = ({0,1,100,1000,10000,100000});
	int valid = npc!=0;
	if(npc){
		foreach(defenses,int defense){
			int target = (int)pow(defense,0.3);
			int previous = npc->query_dynamic_npc_life_scale(100,defense);
			if(target<1)
				target = 1;
			if(previous!=1000)
				valid = 0;
			for(int level=101;level<=124;level++){
				int scale = npc->query_dynamic_npc_life_scale(level,defense);
				if(level<122 && scale>target*1000)
					valid = 0;
				if(level>=122 && scale!=target*1000)
					valid = 0;
				if(scale<previous)
					valid = 0;
				previous = scale;
			}
		}
	}
	check("101-121级生命平滑并在122级恢复历史倍率",valid,
		"生命倍率端点、单调性或122级历史值不成立");
	if(npc)
		destruct(npc);
}

void test_runtime_stats_and_boss_multipliers()
{
	object player = clone(GAMELIB_USER);
	object level_100 = make_dynamic_npc(100,0,0);
	object level_101 = make_dynamic_npc(101,0,0);
	object base_120 = make_dynamic_npc(120,0,0);
	object scaled_120 = make_dynamic_npc(120,0,0);
	object elite_120 = make_dynamic_npc(120,0,1);
	object boss_120 = make_dynamic_npc(120,1,0);
	object base_122 = make_dynamic_npc(122,0,0);
	object scaled_122 = make_dynamic_npc(122,0,0);
	int valid = objectp(player) && objectp(level_100) &&
		objectp(level_101) && objectp(base_120) &&
		objectp(scaled_120) && objectp(elite_120) &&
		objectp(boss_120) && objectp(base_122) &&
		objectp(scaled_122);
	if(valid){
		player->set_name("__testunit_dynamic_npc_scale__");
		player->set_raceId("human");
		player->set_profeId("zhenyue");
		player->setup_player("human","zhenyue");
		player->set_profeId("");
		player->set_base_defend(100000);
		level_100->setup_npc_dongtai(player);
		level_101->setup_npc_dongtai(player);
		player->set_base_defend(1);
		base_120->setup_npc_dongtai(player);
		base_122->setup_npc_dongtai(player);
		player->set_base_defend(1000);
		scaled_120->setup_npc_dongtai(player);
		elite_120->setup_npc_dongtai(player);
		boss_120->setup_npc_dongtai(player);
		scaled_122->setup_npc_dongtai(player);
		int life_scale_120 = scaled_120->query_dynamic_npc_life_scale(
			120,1000);
		int expected_life_120 = base_120->get_cur_life()/10*
			life_scale_120/1000*10;
		valid = level_101->get_cur_life()<
			level_100->get_cur_life()*2 &&
			scaled_120->get_cur_life()==expected_life_120 &&
			scaled_120->get_cur_life()<base_120->get_cur_life()*7 &&
			scaled_122->get_cur_life()==base_122->get_cur_life()*7 &&
			elite_120->get_cur_life()==
			scaled_120->get_cur_life()*3 &&
			boss_120->get_cur_life()==
			scaled_120->get_cur_life()*6;
	}
	check("真实NPC属性无101级断崖且精英/Boss倍率保持3/6倍",
		valid,"动态属性或既有精英/Boss倍率发生偏移");
	if(level_100)
		destruct(level_100);
	if(level_101)
		destruct(level_101);
	if(base_120)
		destruct(base_120);
	if(scaled_120)
		destruct(scaled_120);
	if(elite_120)
		destruct(elite_120);
	if(boss_120)
		destruct(boss_120);
	if(base_122)
		destruct(base_122);
	if(scaled_122)
		destruct(scaled_122);
	if(player)
		destruct(player);
}

int main()
{
	werror("\n=== 动态怪等级断层回归 ===\n");
	test_scale_boundaries();
	test_no_level_101_cliff();
	test_life_scale_transition();
	test_runtime_stats_and_boss_multipliers();
	werror("动态怪断层测试: %d通过/%d失败\n",
		test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
