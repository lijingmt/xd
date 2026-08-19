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

void test_s1_abyss_victory_result_is_not_room_dump()
{
	object room = clone(ROOT+"/gamelib/d/illusion_s1/abyss_garden.pike");
	object player = create_player("__testunit_quick_abyss__");
	object|zero npc = 0;
	object command = (object)(ROOT+"/lowlib/wapmud2/cmds/kill_quick.pike");
	object|zero original_player = this_player();
	string response = "";
	string error_desc = "";
	string target_name = "";
	int same_name_count;
	int exact_name_count;
	int target_accepts_own_id;
	int direct_present_found;
	mixed err = catch {
		player->level = 69;
		player->set_att_by_level();
		player->flush_life();
		player->set_jingli(100);
		player["/tmp/illusion_move_bypass"]=1;
		player->move(room);
		player->m_delete_foruser("/tmp/illusion_move_bypass");
		if(environment(player)!=room)
			error("测试人物未能进入渊花庭\n");
		// 只选择房间正常刷新、且对该玩家真实可见的 S1 怪。另行 clone
		// 的测试怪没有逻辑区归属，本就应该被隔离层隐藏，不能拿来冒充
		// 浏览器实际点击的目标。
		foreach(all_inventory(room,player),object current){
			if(current->is("npc") && current->query_name_cn()=="渊花异兽"){
				if(!npc)
					npc=current;
				same_name_count++;
			}
		}
		if(!npc)
			error("渊花庭没有生成玩家可见的渊花异兽\n");
		target_name=(string)(npc->query_name() || "");
		target_accepts_own_id=target_name!="" && npc->id(target_name);
		foreach(all_inventory(room,player),object current)
			if(functionp(current->query_name) &&
			   (string)current->query_name()==target_name)
				exact_name_count++;
		direct_present_found=!!present(target_name,room,0,player);
		npc->set_base_life(1);
		npc->set_base_str(1);
		npc->flush_life();
		player->m_delete_foruser("/tmp/qkill");
		set_this_player(player);
		command->main(target_name+" 0");
		response = (string)player->query_spliter()["text"];
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);
	check("渊花庭同名怪快速攻击返回明确战果而非裸房间快照",
		!err && same_name_count>=2 &&
		(search(response,"战斗胜利")!=-1 ||
		 search(response,"战斗失败")!=-1) &&
		search(response,"[返回:look]")!=-1 &&
		search(response,"westeastnorth")==-1,
		error_desc+sprintf(" target_name=%O same_name_count=%d exact=%d "+
			"self_id=%d direct_present=%d response=%O",target_name,
			same_name_count,exact_name_count,target_accepts_own_id,
			direct_present_found,response));
	cleanup(player);
	cleanup(room);
}

void test_extreme_stalemate_is_bounded()
{
	object room=clone(WAP_ROOM);
	object player=create_player("__testunit_quick_bounded__");
	object npc=clone(ROOT+"/gamelib/clone/npc/mihuandao/9youdangelang");
	object command=(object)(ROOT+"/lowlib/wapmud2/cmds/kill_quick.pike");
	object|zero original_player=this_player();
	string response="";
	string error_desc="";
	int npc_max;
	int elapsed_ms;
	mixed err=catch{
		player->set_base_life(1000000000);
		player->flush_life();
		player->move(room);
		npc->set_base_life(1000000000);
		npc->set_base_str(1);
		npc->flush_life();
		npc->move(room);
		npc_max=npc->query_life_max();
		player->m_delete_foruser("/tmp/qkill");
		set_this_player(player);
		int started_ms=(System.Time()->usec_full)/1000;
		command->main(npc->query_name()+" 0");
		elapsed_ms=(System.Time()->usec_full)/1000-started_ms;
		response=(string)player->query_spliter()["text"];
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc=describe_error(err);
	check("极端高血低伤快速战斗有界且不伪造击杀",
		!err && npc && npc->get_cur_life()==npc_max &&
		!player->enemy && !npc->enemy &&
		search(response,"512轮内未分胜负")!=-1 &&
		elapsed_ms<3000 &&
		search(response,"[继续:kill_quick")==-1,
		error_desc+sprintf(" npc=%d/%d player=%d elapsed_ms=%d response=%O",
			npc ? npc->get_cur_life() : -1,npc_max,
			player ? player->get_cur_life() : -1,elapsed_ms,response));
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
	test_s1_abyss_victory_result_is_not_room_dump();
	test_extreme_stalemate_is_bounded();
	test_notice_is_one_shot();
	test_source_contract();
	werror("快速攻击安全测试：失败 %d\n",failures);
	return failures ? 1 : 0;
}
