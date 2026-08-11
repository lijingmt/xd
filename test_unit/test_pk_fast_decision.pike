#!/usr/bin/env pike
/** 严格1v1玩家PK超回合快速决胜运行时回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total":0,
	"passed":0,
	"failed":0,
]);

void test_start(string name){
	test_results["total"]++;
	werror("\n[PVP快速决胜 %d] %s\n",test_results["total"],name);
}
void test_pass(){ test_results["passed"]++; werror("  ✓ 通过\n"); }
void test_fail(string reason){
	test_results["failed"]++;
	werror("  ✗ 失败: %s\n",reason);
}

object create_player(string name,string profession,int level)
{
	object player = clone(GAMELIB_USER);
	string race = search(({"jianxian","yushi","zhuxian"}),profession)!=-1 ?
		"human" : (search(({"kuangyao","wuyao","yinggui"}),
		profession)!=-1 ? "monst" : "third");
	player->set_name(name);
	player->name_cn = name;
	player->sid = "5dwap";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race);
	player->set_profeId(profession);
	player->setup_player(race,profession);
	player->level = level;
	player->set_att_by_level();
	player->flush_life();
	player->set_mofa(player->query_mofa_max());
	return player;
}

void start_killing(object attacker,object defender,object room)
{
	attacker->move(room);
	defender->move(room);
	attacker->kill(defender,0);
	if(!defender->query_in_combat())
		defender->_fight(attacker);
}

void cleanup_player(object|zero player)
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

void test_configuration_and_simulation()
{
	test_start("90回合触发、最多1000轮且模拟只读真实气血");
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object attacker = create_player("__testunit_pk_sim_a__","zhenyue",120);
	object defender = create_player("__testunit_pk_sim_b__","jianxian",100);
	mapping result = ([]);
	int attacker_life;
	int defender_life;
	string error_desc = "";
	mixed err = catch {
		start_killing(attacker,defender,room);
		attacker_life = attacker->get_cur_life();
		defender_life = defender->get_cur_life();
		result = attacker->query_pk_fast_decision_simulation(defender);
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && attacker->query_pk_fast_decision_trigger_rounds()==90 &&
	   attacker->query_pk_fast_decision_rounds()==1000 &&
	   result["rounds"]>0 && result["rounds"]<=1000 &&
	   result["winner"] && result["loser"] &&
	   result["winner"]!=result["loser"] &&
	   attacker->get_cur_life()==attacker_life &&
	   defender->get_cur_life()==defender_life)
		test_pass();
	else
		test_fail("配置、结果或只读约束失败: "+error_desc+
			" result="+sprintf("%O",result));
	cleanup_player(attacker);
	cleanup_player(defender);
}

void test_stable_tie_break()
{
	test_start("完全同属性时两侧推演结论一致且主动杀戮者承担风险");
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object attacker = create_player("__testunit_pk_tie_a__","zhenyue",80);
	object defender = create_player("__testunit_pk_tie_b__","zhenyue",80);
	mapping from_attacker = ([]);
	mapping from_defender = ([]);
	string error_desc = "";
	mixed err = catch {
		start_killing(attacker,defender,room);
		from_attacker = attacker->query_pk_fast_decision_simulation(defender);
		from_defender = defender->query_pk_fast_decision_simulation(attacker);
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && from_attacker["winner"]==defender &&
	   from_attacker["loser"]==attacker &&
	   from_defender["winner"]==defender &&
	   from_defender["loser"]==attacker)
		test_pass();
	else
		test_fail("平局规则不稳定: "+error_desc);
	cleanup_player(attacker);
	cleanup_player(defender);
}

void test_round_gate_and_real_settlement()
{
	test_start("89回合不触发，双方满90回合后只结算一次正常死亡");
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	// 让高等级一方以1点气血落败，可绕开测试帐号未登记荣誉档案，
	// 同时仍完整执行真实玩家死亡与战斗清理链。
	object attacker = create_player("__testunit_pk_gate_a__","jianxian",100);
	object defender = create_player("__testunit_pk_gate_b__","zhenyue",120);
	int before = -1;
	int settled = -1;
	int combat_ended = 0;
	int locks_cleared = 0;
	string error_desc = "";
	mixed err = catch {
		start_killing(attacker,defender,room);
		defender->set_life(1);
		attacker->timeCount = 89;
		defender->timeCount = 89;
		before = attacker->check_pk_fast_decision();
		attacker->timeCount = 90;
		defender->timeCount = 90;
		settled = attacker->check_pk_fast_decision();
		combat_ended = !attacker->query_in_combat() &&
			!defender->query_in_combat();
		locks_cleared = !attacker["/tmp/pk_fast_decision/running"] &&
			!defender["/tmp/pk_fast_decision/running"];
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && before==0 && settled==1 && combat_ended && locks_cleared)
		test_pass();
	else
		test_fail(sprintf("before=%d settled=%d ended=%d locks=%d: %s",
			before,settled,combat_ended,locks_cleared,error_desc));
	cleanup_player(attacker);
	cleanup_player(defender);
}

void test_non_pk_and_multi_party_boundaries()
{
	test_start("切磋、打怪和第三方参战均不能触发快速决胜");
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object duelist = create_player("__testunit_pk_duel_a__","zhenyue",80);
	object duel_target = create_player("__testunit_pk_duel_b__","zhenyue",80);
	object hunter = create_player("__testunit_pk_npc_a__","zhenyue",80);
	object attacker = create_player("__testunit_pk_multi_a__","zhenyue",80);
	object defender = create_player("__testunit_pk_multi_b__","jianxian",80);
	object third = create_player("__testunit_pk_multi_c__","kuangyao",80);
	object wolf = clone(ROOT+
		"/gamelib/clone/npc/mihuandao/9youdangelang");
	int duel_ready = -1;
	int npc_ready = -1;
	int multi_ready = -1;
	string error_desc = "";
	mixed err = catch {
		duelist->move(room);
		duel_target->move(room);
		duelist->fight(duel_target,0,1);
		duel_ready = duelist->query_pk_fast_decision_ready(duel_target);
		hunter->move(room);
		wolf->move(room);
		hunter->kill(wolf,0);
		npc_ready = hunter->query_pk_fast_decision_ready(wolf);
		start_killing(attacker,defender,room);
		third->move(room);
		attacker->flush_targets(third,50);
		multi_ready = attacker->query_pk_fast_decision_ready(defender);
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && duel_ready==0 && npc_ready==0 && multi_ready==0)
		test_pass();
	else
		test_fail(sprintf("duel=%d npc=%d multi=%d: %s",
			duel_ready,npc_ready,multi_ready,error_desc));
	cleanup_player(duelist);
	cleanup_player(duel_target);
	cleanup_player(hunter);
	cleanup_player(attacker);
	cleanup_player(defender);
	cleanup_player(third);
	if(wolf)
		destruct(wolf);
}

void test_fangshi_summon_side()
{
	test_start("方士合法灵兽归入主人一侧且计入战斗快照");
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object fangshi = create_player("__testunit_pk_summon_a__","fangshi",60);
	object defender = create_player("__testunit_pk_summon_b__","jianxian",60);
	object|zero tiger = 0;
	mapping profile = ([]);
	int ready = 0;
	string error_desc = "";
	mixed err = catch {
		fangshi->skills["huling"] = ({1,0});
		start_killing(fangshi,defender,room);
		tiger = SUMMOND->summon_creature(
			fangshi->query_name(),"huling",1,1);
		if(tiger){
			defender->flush_targets(tiger,100);
			defender->enemy = tiger;
			profile = fangshi->query_pk_fast_side_profile(fangshi);
			ready = fangshi->query_pk_fast_decision_ready(defender);
		}
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && tiger &&
	   fangshi->query_pk_fast_target_owner(tiger)==fangshi && ready==1 &&
	   profile["life"]>fangshi->get_cur_life() &&
	   profile["physical_raw"]>0)
		test_pass();
	else
		test_fail("灵兽归属或快照失败: "+error_desc+
			" profile="+sprintf("%O",profile));
	cleanup_player(fangshi);
	cleanup_player(defender);
}

void test_tianxiang_magic_profile()
{
	test_start("天象作为纯法系进入快速决胜魔法快照");
	object mage = create_player("__testunit_pk_tianxiang__","tianxiang",80);
	mapping profile = ([]);
	string error_desc = "";
	mixed err = catch {
		profile = mage->query_pk_fast_side_profile(mage);
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && profile["magic_enabled"]==1 &&
	   profile["magic_raw"]>profile["physical_raw"])
		test_pass();
	else
		test_fail("天象魔法快照未接线: "+error_desc+
			" profile="+sprintf("%O",profile));
	cleanup_player(mage);
}

void test_lingyi_heal_profile()
{
	test_start("灵医快速决胜只折算已学、可支付且受减疗约束的治疗");
	object healer = create_player("__testunit_pk_lingyi__","lingyi",80);
	mapping normal = ([]);
	mapping reduced = ([]);
	mapping unlearned = ([]);
	mapping malformed = ([]);
	string error_desc = "";
	mixed err = catch {
		healer->skills["huichun"] = ({1,0});
		normal = healer->query_pk_fast_side_profile(healer);
		healer->set_debuff("curse",0,"life");
		healer->set_debuff("curse",1,1000);
		healer->set_debuff("curse",2,10);
		reduced = healer->query_pk_fast_side_profile(healer);
		healer->clean_debuff("curse");
		m_delete(healer->skills,"huichun");
		unlearned = healer->query_pk_fast_side_profile(healer);
		healer->skills["huichun"] = ({});
		malformed = healer->query_pk_fast_side_profile(healer);
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && normal["magic_enabled"]==1 &&
	   normal["profession_heal"]>0 &&
	   reduced["profession_heal"]>0 &&
	   reduced["profession_heal"]<=normal["profession_heal"]/10+1 &&
	   unlearned["profession_heal"]==0 &&
	   malformed["profession_heal"]==0)
		test_pass();
	else
		test_fail("灵医治疗快照边界未接线: "+error_desc+
			" normal="+sprintf("%O",normal)+
			" reduced="+sprintf("%O",reduced)+
			" unlearned="+sprintf("%O",unlearned)+
			" malformed="+sprintf("%O",malformed));
	cleanup_player(healer);
}

void configure_test_pet(object player,string species,string opponent_id)
{
	player["/tmp/wanling/pet_id"] = player->query_name()+"-pet";
	player["/tmp/wanling/species"] = species;
	player["/tmp/wanling/pet_level"] = 60;
	player["/tmp/wanling/player_level"] = player->query_level();
	player["/tmp/wanling/skill_set"] = 0;
	player["/tmp/wanling/pet_pvp_growth_percent"] = 124;
	player["/tmp/wanling/pvp_target"] = opponent_id;
	player["/tmp/wanling/pvp_charge"] = 0;
	player["/tmp/wanling/pvp_uses"] = 0;
}

void test_pet_fast_decision_parity()
{
	test_start("快速决胜只模拟双方剩余两次御灵且不改写真实充能");
	object room = (object)(ROOT+
		"/gamelib/d/congxianzhen/congxianzhenguangchang");
	object attacker = create_player("__testunit_pk_pet_a__","zhenyue",80);
	object defender = create_player("__testunit_pk_pet_b__","zhenyue",80);
	mapping result = ([]);
	string error_desc = "";
	mixed err = catch {
		configure_test_pet(attacker,"dangkang",defender->query_name());
		configure_test_pet(defender,"dangkang",attacker->query_name());
		start_killing(attacker,defender,room);
		result = attacker->query_pk_fast_decision_simulation(defender);
	};
	if(err)
		error_desc = describe_error(err);
	if(!err && (int)result["me_pet_triggers"]==2 &&
	   (int)result["target_pet_triggers"]==2 &&
	   (int)attacker["/tmp/wanling/pvp_charge"]==0 &&
	   (int)defender["/tmp/wanling/pvp_charge"]==0 &&
	   (int)attacker["/tmp/wanling/pvp_uses"]==0 &&
	   (int)defender["/tmp/wanling/pvp_uses"]==0)
		test_pass();
	else
		test_fail("御灵次数、模拟只读或双方对称性失败: "+error_desc+
			" result="+sprintf("%O",result));
	cleanup_player(attacker);
	cleanup_player(defender);
}

int main(int argc,array(string) argv)
{
	werror("\n╔════════════════════════════════════════════════╗\n");
	werror("║             PVP快速决胜测试                  ║\n");
	werror("╚════════════════════════════════════════════════╝\n");
	test_configuration_and_simulation();
	test_stable_tie_break();
	test_round_gate_and_real_settlement();
	test_non_pk_and_multi_party_boundaries();
	test_fangshi_summon_side();
	test_tianxiang_magic_profile();
	test_lingyi_heal_profile();
	test_pet_fast_decision_parity();
	werror("\nPVP快速决胜：%d通过，%d失败\n",
		test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
