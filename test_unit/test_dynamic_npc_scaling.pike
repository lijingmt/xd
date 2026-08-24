#!/usr/bin/env pike
/** 动态怪 100-122 级属性与生命平滑衔接回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

array(mapping(string:string)) physical_professions = ({
	(["race":"human","profession":"jianxian"]),
	(["race":"human","profession":"yushi"]),
	(["race":"human","profession":"zhuxian"]),
	(["race":"monst","profession":"kuangyao"]),
	(["race":"monst","profession":"wuyao"]),
	(["race":"monst","profession":"yinggui"]),
	(["race":"third","profession":"fangshi"]),
	(["race":"third","profession":"zhenyue"]),
	(["race":"third","profession":"tianxiang"]),
	(["race":"third","profession":"lingyi"]),
	(["race":"third","profession":"wuxiang"]),
	(["race":"third","profession":"taiji"]),
});

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

object make_physical_test_player(string name,string race,string profession,
	int defense)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->set_raceId(race);
	player->set_profeId(profession);
	player->setup_player(race,profession);
	player->set_base_defend(defense);
	return player;
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
			// 数值整备：防御^0.3倍率封顶5倍，防止套装强化后属性爆炸。
			if(target>5)
				target = 5;
			// 数值整备：防御^0.3倍率封顶5倍（套装强化后防爆炸）。
			if(target>5)
				target = 5;
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
	if(target_multiplier>5)
		target_multiplier = 5;
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
			if(target>5)
				target = 5;
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
			scaled_120->get_cur_life()<base_120->get_cur_life()*6 &&
			scaled_122->get_cur_life()==base_122->get_cur_life()*5 &&
			elite_120->get_cur_life()==
			scaled_120->get_cur_life()*3 &&
			boss_120->get_cur_life()==
			scaled_120->get_cur_life()*3;
	}
	check("真实NPC属性无101级断崖且精英/Boss倍率保持3/3倍",
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

void test_all_professions_share_dynamic_physical_defense_rule()
{
	array(int) levels = ({70,100,101,120,150});
	int valid = 1;
	string reason = "";
	int player_index = 0;
	foreach(physical_professions,mapping(string:string) profile){
		object player = make_physical_test_player(
			"__testunit_dynamic_physical_"+player_index+"__",
			profile["race"],profile["profession"],100000);
		if(!player){
			valid = 0;
			reason = "无法创建职业 "+profile["profession"];
			break;
		}
		foreach(levels,int level){
			object baseline_player = make_physical_test_player(
				"__testunit_dynamic_baseline_"+player_index+"_"+level+"__",
				"human","jianxian",1);
			object baseline = make_dynamic_npc(level,0,0);
			object scaled = make_dynamic_npc(level,0,0);
			int expected = 0;
			int actual = 0;
			int effective = 0;
			int scale = 0;
			if(!baseline_player || !baseline || !scaled){
				valid = 0;
				reason = "动态怪测试对象创建失败";
			}
			else{
				// 基准玩家不携带职业力量，确保动态倍率精确为1。
				baseline_player->set_profeId("");
				baseline->setup_npc_dongtai(baseline_player);
				scaled->setup_npc_dongtai(player);
				expected = baseline->query_defend_power();
				actual = scaled->query_defend_power();
				effective = player->query_effective_physical_defense(
					player,scaled);
				scale = scaled->
					query_dynamic_npc_physical_defense_scale_applied();
				if(abs(effective-expected)>2 || effective>actual ||
				   (level<=100 && (scale!=1000 || effective!=actual)) ||
				   (level>100 && (scale<=1000 || actual<=effective))){
					valid = 0;
					reason = sprintf(
						"%s Lv%d scale=%d base=%d actual=%d effective=%d",
						profile["profession"],level,scale,expected,
						actual,effective);
				}
			}
			if(baseline_player)
				destruct(baseline_player);
			if(baseline)
				destruct(baseline);
			if(scaled)
				destruct(scaled);
			if(!valid)
				break;
		}
		destruct(player);
		if(!valid)
			break;
		player_index++;
	}
	check("十二职业在70/100/101/120/150级共用动态物防归一规则",
		valid,reason);
}

void test_fixed_boss_pvp_and_npc_combat_unchanged()
{
	object attacker = make_physical_test_player(
		"__testunit_dynamic_boundary_attacker__","third","zhenyue",100000);
	object target_player = make_physical_test_player(
		"__testunit_dynamic_boundary_target__","human","jianxian",50000);
	object fixed_npc = make_dynamic_npc(150,0,0);
	object dynamic_boss = make_dynamic_npc(150,1,0);
	object dynamic_npc = make_dynamic_npc(150,0,0);
	object npc_attacker = make_dynamic_npc(150,0,0);
	int valid = !!attacker && !!target_player && !!fixed_npc &&
		!!dynamic_boss && !!dynamic_npc && !!npc_attacker;
	if(valid){
		int effective_before;
		int effective_after;
		fixed_npc->setup_npc();
		dynamic_boss->setup_npc_dongtai(attacker);
		dynamic_npc->setup_npc_dongtai(attacker);
		npc_attacker->setup_npc();
		effective_before = attacker->query_effective_physical_defense(
			attacker,dynamic_npc);
		dynamic_npc->set_base_str(500);
		dynamic_npc->set_base_defend(777);
		dynamic_npc->set_buff("buff",0,"defend");
		dynamic_npc->set_buff("buff",1,333);
		effective_after = attacker->query_effective_physical_defense(
			attacker,dynamic_npc);
		valid = attacker->query_effective_physical_defense(
			attacker,target_player)==target_player->query_defend_power() &&
			attacker->query_effective_physical_defense(
				attacker,fixed_npc)==fixed_npc->query_defend_power() &&
			attacker->query_effective_physical_defense(
				attacker,dynamic_boss)==dynamic_boss->query_defend_power() &&
			attacker->query_effective_physical_defense(
				npc_attacker,dynamic_npc)==dynamic_npc->query_defend_power() &&
			effective_after< dynamic_npc->query_defend_power() &&
			effective_after==effective_before+500*2+777+333;
	}
	check("固定怪、Boss、PvP与NPC互殴保持原物防",
		valid,"非动态玩家PvE边界发生变化");
	if(attacker) destruct(attacker);
	if(target_player) destruct(target_player);
	if(fixed_npc) destruct(fixed_npc);
	if(dynamic_boss) destruct(dynamic_boss);
	if(dynamic_npc) destruct(dynamic_npc);
	if(npc_attacker) destruct(npc_attacker);
}

void test_all_physical_entry_points_use_unified_defense()
{
	string fight = Stdio.read_file(ROOT+
		"/lowlib/wapmud2/inherit/feature/fight.pike") || "";
	string quick = Stdio.read_file(ROOT+
		"/lowlib/wapmud2/cmds/kill_quick.pike") || "";
	int helper_uses = sizeof(fight/"query_effective_physical_defense(")-1;
	int valid = helper_uses>=4 &&
		search(fight,"query_effective_physical_defense(attacker,target)")!=-1 &&
		search(fight,"query_effective_physical_defense(\n\t\t\t\tthis_object(),enemy)")!=-1 &&
		search(quick,"me->query_effective_physical_defense(me,ob)")!=-1;
	check("普攻、物理技能、快速结算、召唤物与旧速战统一入口",
		valid,sprintf("fight helper uses=%d",helper_uses));
}

int main()
{
	werror("\n=== 动态怪等级断层回归 ===\n");
	test_scale_boundaries();
	test_no_level_101_cliff();
	test_life_scale_transition();
	test_runtime_stats_and_boss_multipliers();
	test_all_professions_share_dynamic_physical_defense_rule();
	test_fixed_boss_pvp_and_npc_combat_unchanged();
	test_all_physical_entry_points_use_unified_defense();
	werror("动态怪断层测试: %d通过/%d失败\n",
		test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
