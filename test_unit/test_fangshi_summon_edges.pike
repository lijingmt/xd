#!/usr/bin/env pike
/**
 * 方士召唤兽边界与生命周期运行时测试。
 *
 * 覆盖服务端鉴权时长、三灵原子性、状态封装、存活共鸣、
 * 目标切换、龟灵嘲讽、鹤灵成长、PVP保护、死亡清理和击杀归属。
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
	werror("\n[方士召唤边界 %d] %s\n",test_results["total"],name);
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

object create_player(string name,string race_id,
	string profession_id,int level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "召唤边界测试人物";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race_id);
	player->set_profeId(profession_id);
	player->setup_player(race_id,profession_id);
	player->level = level;
	player->set_att_by_level();
	player->flush_life();
	player->set_mofa(player->query_mofa_max());
	if(profession_id=="fangshi")
		player->skills["lingdanshu"] = ({1,0});
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	SUMMOND->dismiss_all(player->query_name());
	if(player->query_in_combat())
		player->_clean_fight();
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

void test_server_duration_and_state_copy()
{
	test_start("服务端忽略伪造时长等级且召唤列表不能反向篡改");
	string name = "__testunit_summon_duration__";
	object player = create_player(name,"third","fangshi",60);
	object room = clone(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero tiger = 0;
	int duration = 0;
	int skill_level = 0;
	int copy_isolated = 0;
	int recovered = 0;
	string error_desc = "";

	mixed err = catch {
		player->skills["huling"] = ({2,0});
		player->move(room);
		tiger = SUMMOND->summon_creature(name,"huling",999999,999);
		if(tiger){
			duration = tiger->query_summon_duration();
			skill_level = tiger->query_summon_skill_level();
			mapping summons = SUMMOND->get_player_summons(name);
			m_delete(summons,"huling");
			copy_isolated =
				SUMMOND->get_current_summon_count(name)==1;
			SUMMOND->remove_creature_record(name,"huling");
			recovered = SUMMOND->register_existing_summon(
				name,"huling",tiger);
		}
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && tiger && duration==720 && skill_level==2 &&
	   copy_isolated && recovered &&
	   SUMMOND->get_current_summon_count(name)==1)
		test_pass();
	else
		test_fail(sprintf(
			"时长=%d 等级=%d 副本=%d 恢复=%d: %s",
			duration,skill_level,copy_isolated,recovered,error_desc));

	destroy_player(player);
	if(room)
		destruct(room);
}

void test_three_spirit_level_and_atomic_fill()
{
	test_start("50级不产生半套三灵且60级一次补齐完整组合");
	string low_name = "__testunit_summon_all_50__";
	string high_name = "__testunit_summon_all_60__";
	object low = create_player(low_name,"third","fangshi",50);
	object high = create_player(high_name,"third","fangshi",60);
	object room = clone(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	int low_result = -1;
	int low_count = -1;
	int filled = -1;
	int high_count = -1;
	string error_desc = "";

	mixed err = catch {
		low->skills["sanlingheyi"] = ({1,0});
		high->skills["sanlingheyi"] = ({1,0});
		high->skills["huling"] = ({1,0});
		low->move(room);
		high->move(room);
		low_result = SUMMOND->summon_all_spirits(
			low_name,999999,999);
		low_count = SUMMOND->get_current_summon_count(low_name);
		SUMMOND->summon_creature(high_name,"huling",1,999);
		filled = SUMMOND->summon_all_spirits(
			high_name,999999,999);
		high_count = SUMMOND->get_current_summon_count(high_name);
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && low_result==0 && low_count==0 &&
	   filled==2 && high_count==3)
		test_pass();
	else
		test_fail(sprintf(
			"50级结果=%d/%d 60级补齐=%d/%d: %s",
			low_result,low_count,filled,high_count,error_desc));

	destroy_player(low);
	destroy_player(high);
	if(room)
		destruct(room);
}

void test_living_resonance_and_crane_growth()
{
	test_start("死亡鹤灵不参与共鸣、不治疗且治疗量随技能成长");
	string name = "__testunit_summon_crane__";
	object player = create_player(name,"third","fangshi",60);
	object room = clone(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero crane = 0;
	int low_heal = 0;
	int high_heal = 0;
	int dead_life = 0;
	mapping state = ([]);
	mapping result = ([]);
	string error_desc = "";

	mixed err = catch {
		player->skills["heling"] = ({1,0});
		player->move(room);
		crane = SUMMOND->summon_creature(name,"heling",600,1);
		if(crane){
			int base_life = 1;
			player->set_life(base_life);
			crane->set_summon_skill_level(1);
			crane->heal_master();
			low_heal = player->get_cur_life()-base_life;
			player->set_life(base_life);
			crane->set_summon_skill_level(5);
			crane->heal_master();
			high_heal = player->get_cur_life()-base_life;
			crane->set_life(0);
			player->set_life(base_life);
			crane->heal_master();
			dead_life = player->get_cur_life();
			state = SUMMOND->get_resonance_state(player);
			result = SUMMOND->activate_resonance(player);
		}
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && crane && high_heal>low_heal && low_heal>0 &&
	   dead_life==1 && state["count"]==0 &&
	   result["success"]==0 && result["reason"]=="no_summon")
		test_pass();
	else
		test_fail(sprintf(
			"低级治疗=%d 高级治疗=%d 死亡后生命=%d 共鸣=%d: %s",
			low_heal,high_heal,dead_life,state["count"],error_desc));

	if(crane)
		destruct(crane);
	destroy_player(player);
	if(room)
		destruct(room);
}

void test_target_switch_and_turtle_taunt()
{
	test_start("灵兽立即切换主人目标且龟灵压过最高仇恨");
	string name = "__testunit_summon_combat__";
	object player = create_player(name,"third","fangshi",60);
	object first = create_player(
		"__testunit_summon_enemy_1__","human","yushi",60);
	object second = create_player(
		"__testunit_summon_enemy_2__","human","yushi",60);
	object room = clone(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero tiger = 0;
	object|zero turtle = 0;
	int switched = 0;
	int taunted = 0;
	string error_desc = "";

	mixed err = catch {
		player->skills["huling"] = ({1,0});
		player->skills["guiling"] = ({1,0});
		player->move(room);
		first->move(room);
		second->move(room);
		tiger = SUMMOND->summon_creature(name,"huling",600,1);
		turtle = SUMMOND->summon_creature(name,"guiling",600,1);
		if(tiger && turtle){
			tiger->focus_summon_target(first);
			tiger->flush_targets(first,1000);
			tiger->focus_summon_target(second);
			switched = tiger->query_enemy()==second &&
				tiger->targets[second]==100 &&
				!tiger->targets[first];

			second->_fight(player);
			second->flush_targets(player,1000);
			turtle->taunt_enemies();
			taunted = second->query_enemy()==turtle &&
				second->targets[turtle]>second->targets[player];
		}
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && switched && taunted)
		test_pass();
	else
		test_fail(sprintf(
			"切换=%d 嘲讽=%d tiger_enemy=%O t1=%d t2=%d "
			"master_life=%d turtle_life=%d enemy_combat=%d "
			"enemy_target=%O owner_hate=%d turtle_hate=%d: %s",
			switched,taunted,tiger ? tiger->query_enemy() : 0,
			tiger ? tiger->targets[first] : -1,
			tiger ? tiger->targets[second] : -1,
			player ? player->get_cur_life() : -1,
			turtle ? turtle->get_cur_life() : -1,
			second ? second->query_in_combat() : -1,
			second ? second->query_enemy() : 0,
			second ? second->targets[player] : -1,
			second && turtle ? second->targets[turtle] : -1,
			error_desc));

	destroy_player(player);
	destroy_player(first);
	destroy_player(second);
	if(room)
		destruct(room);
}

void test_pvp_credit_and_owner_death()
{
	test_start("同阵营决斗可攻击灵兽、击杀归主人且主人死亡立即清理");
	string name = "__testunit_summon_owner_death__";
	object player = create_player(name,"third","fangshi",60);
	object attacker = create_player(
		"__testunit_summon_duelist__","third","fangshi",60);
	object room = clone(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero tiger = 0;
	int ordinary_blocked = 0;
	int duel_allowed = 0;
	int team_blocked = 0;
	int credited = 0;
	int cleared = 0;
	string error_desc = "";

	mixed err = catch {
		player->skills["huling"] = ({1,0});
		player->move(room);
		attacker->move(room);
		tiger = SUMMOND->summon_creature(name,"huling",600,1);
		if(tiger){
			player->kill_flag = 1;
			attacker->kill_flag = 1;
			ordinary_blocked = !tiger->can_be_attacked(attacker);
			player->kill_flag = 0;
			attacker->kill_flag = 0;
			duel_allowed = tiger->can_be_attacked(attacker);
			player->set_term("__testunit_summon_same_team__");
			attacker->set_term("__testunit_summon_same_team__");
			team_blocked = !tiger->can_be_attacked(attacker);
			credited =
				SUMMOND->query_combat_credit_owner(tiger)==player;
			SUMMOND->player_death(name);
			cleared =
				SUMMOND->get_current_summon_count(name)==0 && !tiger;
			tiger = 0;
		}
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && ordinary_blocked && duel_allowed &&
	   team_blocked && credited && cleared)
		test_pass();
	else
		test_fail(sprintf(
			"普通=%d 决斗=%d 队伍=%d 归属=%d 清理=%d: %s",
			ordinary_blocked,duel_allowed,team_blocked,
			credited,cleared,error_desc));

	destroy_player(player);
	destroy_player(attacker);
	if(room)
		destruct(room);
}

void test_wiring_and_duration_clamp()
{
	test_start("HTTP串行入口、死亡归属接线与防御性时长上限");
	object summon = clone(ROOT+
		"/gamelib/clone/npc/summon/huling");
	string thread_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/thread_manager.pike");
	string user_source =
		Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	string npc_source =
		Stdio.read_file(ROOT+"/gamelib/inherit/npc.pike");
	int min_duration = 0;
	int max_duration = 0;
	string error_desc = "";

	mixed err = catch {
		summon->set_summon_duration(0);
		min_duration = summon->query_summon_duration();
		summon->set_summon_duration(999999);
		max_duration = summon->query_summon_duration();
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && min_duration==60 && max_duration==900 &&
	   thread_source && search(thread_source,"\"summon\"")!=-1 &&
	   user_source && search(user_source,
		"SUMMOND->player_death(me->query_name())")!=-1 &&
	   search(user_source,"query_combat_credit_owner")!=-1 &&
	   npc_source && search(npc_source,
		"query_combat_credit_owner")!=-1)
		test_pass();
	else
		test_fail(sprintf(
			"最短=%d 最长=%d 接线缺失: %s",
			min_duration,max_duration,error_desc));

	if(summon)
		destruct(summon);
}

void test_worker_handoff_preserves_expiry_and_hp_ratio()
{
	test_start("跨worker仅恢复一次召唤且不延长时长或刷新生命");
	string name = "__testunit_summon_worker_handoff__";
	object player = create_player(name,"third","fangshi",60);
	object room = clone(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object|zero tiger = 0;
	mapping snapshot = ([]);
	int restored = 0;
	int restored_count = 0;
	int restored_life = 0;
	int restored_life_max = 0;
	int restored_remaining = 0;
	string error_desc = "";

	mixed err = catch {
		player->skills["huling"] = ({2,0});
		player->move(room);
		tiger = SUMMOND->summon_creature(name,"huling",999,999);
		if(tiger){
			tiger->set_life(max(1,tiger->query_life_max()/3));
			snapshot = SUMMOND->snapshot_worker_handoff(player);
			SUMMOND->dismiss_all(name);
			restored = SUMMOND->restore_worker_handoff(player,snapshot);
			mapping summons = SUMMOND->get_player_summons(name);
			tiger = summons["huling"];
			restored_count = SUMMOND->get_current_summon_count(name);
			if(tiger){
				restored_life = tiger->get_cur_life();
				restored_life_max = tiger->query_life_max();
				restored_remaining = tiger->query_summon_remaining();
			}
		}
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && restored==1 && restored_count==1 && tiger &&
	   restored_life>0 && restored_life_max>0 &&
	   restored_life*100/restored_life_max>=32 &&
	   restored_life*100/restored_life_max<=34 &&
	   restored_remaining>0 && restored_remaining<=720)
		test_pass();
	else
		test_fail(sprintf(
			"恢复=%d/%d 生命=%d/%d 剩余=%d: %s",
			restored,restored_count,restored_life,restored_life_max,
			restored_remaining,error_desc));

	destroy_player(player);
	if(room)
		destruct(room);
}

void print_summary()
{
	werror("\n========================================\n");
	werror("方士召唤边界测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	werror("========================================\n");
}

int main()
{
	test_server_duration_and_state_copy();
	test_three_spirit_level_and_atomic_fill();
	test_living_resonance_and_crane_growth();
	test_target_switch_and_turtle_taunt();
	test_pvp_credit_and_owner_death();
	test_wiring_and_duration_clamp();
	test_worker_handoff_preserves_expiry_and_hp_ratio();
	print_summary();
	return test_results["failed"] == 0 ? 0 : 1;
}
