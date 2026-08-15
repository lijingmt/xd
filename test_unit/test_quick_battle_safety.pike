#!/usr/bin/env pike
/** 快速攻击低等级、目标类型与死亡复活回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

int failures;

void check(string name,int valid,string detail)
{
	if(valid)
		werror("[快速攻击安全] ✓ %s\n",name);
	else{
		failures++;
		werror("[快速攻击安全] ✗ %s: %s\n",name,detail);
	}
}

object create_player(string name)
{
	object player = clone(GAMELIB_USER);
	player->set_name(name);
	player->name_cn = "快速攻击测试角色";
	player->sid = "5dwap";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level = 1;
	player->set_att_by_level();
	player->flush_life();
	player->set_mofa(player->query_mofa_max());
	player->set_jingli(100);
	player->all_fee = 1000;
	return player;
}

void cleanup(object|zero ob)
{
	if(!ob)
		return;
	if(ob->is("player")){
		catch { SUMMOND->dismiss_all(ob->query_name()); };
		if(ob->query_in_combat())
			ob->_clean_fight();
	}
	foreach(all_inventory(ob),object item)
		destruct(item);
	destruct(ob);
}

void test_low_level_loss_and_revival()
{
	object room = clone(WAP_ROOM);
	object player = create_player("__testunit_quick_low__");
	object npc = clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
	object command = (object)(ROOT+"/lowlib/wapmud2/cmds/kill_quick.pike");
	object|zero original_player = this_player();
	string error_desc = "";
	int npc_max = 0;
	mixed err = catch {
		player->move(room);
		npc->set_base_life(1000000);
		npc->set_base_str(1000000);
		npc->flush_life();
		npc->move(room);
		npc_max = npc->query_life_max();
		player->set_life(1);
		set_this_player(player);
		command->main(npc->query_name()+" 0");
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);
	check("1级角色快速攻击落败不崩溃且保留原死亡血量规则",
		!err && player && player->get_cur_life()<=0 &&
		npc && npc->get_cur_life()==npc_max,
		error_desc+sprintf(" player_life=%d/%d npc_life=%d/%d",
			player ? player->get_cur_life() : -1,
			player ? player->query_life_max() : -1,
			npc ? npc->get_cur_life() : -1,npc_max));
	cleanup(player);
	cleanup(npc);
	cleanup(room);
}

void test_player_target_rejected()
{
	object room = clone(WAP_ROOM);
	object attacker = create_player("__testunit_quick_attacker__");
	object target = create_player("__testunit_quick_target__");
	object command = (object)(ROOT+"/lowlib/wapmud2/cmds/kill_quick.pike");
	object|zero original_player = this_player();
	string error_desc = "";
	string response = "";
	int target_life = target->get_cur_life();
	mixed err = catch {
		attacker->move(room);
		target->move(room);
		set_this_player(attacker);
		command->main(target->query_name()+" 0");
		response = (string)attacker->query_spliter()["text"];
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);
	check("伪造快速攻击玩家目标不会绕过真实PK链",
		!err && !attacker->enemy && !target->enemy &&
		target->get_cur_life()==target_life &&
		search(response,"快速攻击只能用于怪物")!=-1,
		error_desc+sprintf(" target_life=%d/%d response=%O",
			target->get_cur_life(),target_life,response));
	cleanup(attacker);
	cleanup(target);
	cleanup(room);
}

void test_dead_npc_rejected()
{
	object room = clone(WAP_ROOM);
	object player = create_player("__testunit_quick_dead_npc__");
	object npc = clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
	object command = (object)(ROOT+"/lowlib/wapmud2/cmds/kill_quick.pike");
	object|zero original_player = this_player();
	string error_desc = "";
	string response = "";
	int life_before = player->get_cur_life();
	mixed err = catch {
		player->move(room);
		npc->move(room);
		npc->set_life(0);
		set_this_player(player);
		command->main(npc->query_name()+" 0");
		response = (string)player->query_spliter()["text"];
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);
	check("零血怪物不能被快速攻击重复结算",
		!err && npc && npc->get_cur_life()==0 &&
		player->get_cur_life()==life_before && !player->enemy &&
		search(response,"目标已经倒下")!=-1,
		error_desc+sprintf(" player_life=%d/%d npc_life=%d response=%O",
			player->get_cur_life(),life_before,
			npc ? npc->get_cur_life() : -1,response));
	cleanup(player);
	cleanup(npc);
	cleanup(room);
}

void test_source_contract()
{
	string quick = Stdio.read_file(ROOT+
		"/lowlib/wapmud2/cmds/kill_quick.pike") || "";
	string gateway = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/pike_gateway.pike") || "";
	program|zero result_program = 0;
	mixed err = catch {
		result_program = (program)(ROOT+
			"/gamelib/cmds/quick_battle_result.pike");
	};
	check("落败分支不再读取命令对象的life_max",
		search(quick,"this_object()->life_max")==-1 &&
		search(quick,"ob->set_life(ob->query_life_max())")!=-1,
		"快速攻击仍可能在玩家落败时抛字段异常");
	check("跨Worker落败结果改由目标Worker生成安全结果页",
		!err && result_program &&
		search(quick,"stage_worker_quick_battle_notice")!=-1 &&
		search(gateway,"quick_battle_result")!=-1,
		err ? describe_error(err) : "结果交接链未完整接线");
}

void test_notice_is_one_shot()
{
	object player = create_player("__testunit_quick_notice__");
	int staged = player->stage_worker_quick_battle_notice("战斗失败\n");
	string first = player->consume_worker_quick_battle_notice();
	string second = player->consume_worker_quick_battle_notice();
	check("快速战斗跨Worker结果只消费一次",
		staged==1 && first=="战斗失败\n" && second=="",
		sprintf("staged=%d first=%O second=%O",staged,first,second));
	cleanup(player);
}

int main()
{
	werror("\n========== 快速攻击安全测试 ==========\n");
	test_low_level_loss_and_revival();
	test_player_target_rejected();
	test_dead_npc_rejected();
	test_notice_is_one_shot();
	test_source_contract();
	werror("快速攻击安全测试：失败 %d\n",failures);
	return failures ? 1 : 0;
}
