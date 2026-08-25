#!/usr/bin/env pike
/** 组队击杀归属回归：击杀者退队/被移出或队伍解散后仍按单人结算。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[组队击杀归属] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[组队击杀归属] ✗ %s: %s\n",name,detail);
	}
}

object create_test_player(string name)
{
	object player=clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn=name;
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level=20;
	player->set_att_by_level();
	player->set_term("noterm");
	player->exp=0;
	player->current_exp=0;
	player->all_fee=0;
	return player;
}

int total_exp(object player)
{
	return (int)player->exp+(int)player->current_exp;
}

void destroy_test_player(object|zero player)
{
	if(player)
		destruct(player);
}

void cleanup_team(string tid,string leader_id)
{
	if(tid!="" && sizeof(tid)>1 && leader_id!="" &&
	   TERMD->query_termId(tid))
		TERMD->destory_term(tid,leader_id);
}

void test_killer_outside_recorded_team()
{
	object room=clone(WAP_ROOM);
	object npc=clone(ROOT+"/gamelib/clone/npc/wugongdong/chixiewugong18");
	object leader=create_test_player("__testunit_kill_leader__");
	object teammate=create_test_player("__testunit_kill_mate__");
	object killer=create_test_player("__testunit_kill_outsider__");
	string tid="";
	int killer_before=0;
	int killer_after=0;
	mixed err=catch {
		leader->move(room);
		teammate->move(room);
		killer->move(room);
		npc->move(room);
		tid=(string)TERMD->term_create(leader->query_name());
		TERMD->add_termer(tid,teammate->query_name(),
			teammate->query_name_cn());
		npc->term_who_fight_npc=tid;
		npc->who_fight_npc=leader->query_name();
		npc->enemy=killer;
		npc->targets[killer]=1;
		killer_before=total_exp(killer);
		npc->fight_die();
		killer_after=total_exp(killer);
	};
	check("击杀者已不在NPC记录的队伍中仍按单人获得经验",
		!err && killer_after>killer_before,
		err ? describe_error(err) :
			sprintf("killer exp %d -> %d",killer_before,killer_after));
	cleanup_team(tid,leader ? leader->query_name() : "");
	destroy_test_player(leader);
	destroy_test_player(teammate);
	destroy_test_player(killer);
	if(npc)
		destruct(npc);
	if(room)
		destruct(room);
}

void test_disbanded_team_still_credits_killer()
{
	object room=clone(WAP_ROOM);
	object npc=clone(ROOT+"/gamelib/clone/npc/wugongdong/chixiewugong18");
	object leader=create_test_player("__testunit_kill_leader2__");
	object teammate=create_test_player("__testunit_kill_mate2__");
	object killer=create_test_player("__testunit_kill_member2__");
	string tid="";
	int killer_before=0;
	int killer_after=0;
	mixed err=catch {
		leader->move(room);
		teammate->move(room);
		killer->move(room);
		npc->move(room);
		tid=(string)TERMD->term_create(leader->query_name());
		TERMD->add_termer(tid,teammate->query_name(),
			teammate->query_name_cn());
		TERMD->add_termer(tid,killer->query_name(),
			killer->query_name_cn());
		npc->term_who_fight_npc=tid;
		npc->who_fight_npc=leader->query_name();
		npc->enemy=killer;
		npc->targets[killer]=1;
		// 战斗中途整队解散：term id仍在但成员已被清空。
		TERMD->destory_term(tid,leader->query_name());
		killer_before=total_exp(killer);
		npc->fight_die();
		killer_after=total_exp(killer);
	};
	check("战斗中队伍解散成空队后击杀者仍按单人获得经验",
		!err && killer_after>killer_before,
		err ? describe_error(err) :
			sprintf("killer exp %d -> %d",killer_before,killer_after));
	cleanup_team(tid,leader ? leader->query_name() : "");
	destroy_test_player(leader);
	destroy_test_player(teammate);
	destroy_test_player(killer);
	if(npc)
		destruct(npc);
	if(room)
		destruct(room);
}

void test_cross_room_member_shares_exp()
{
	object room_a=clone(WAP_ROOM);
	object room_b=clone(WAP_ROOM);
	object npc=clone(ROOT+"/gamelib/clone/npc/wugongdong/chixiewugong18");
	object leader=create_test_player("__testunit_xroom_leader__");
	object mate=create_test_player("__testunit_xroom_mate__");
	object away=create_test_player("__testunit_xroom_away__");
	string tid="";
	int away_before=0;
	int away_after=0;
	mixed err=catch{
		leader->move(room_a);
		mate->move(room_a);
		away->move(room_b);
		npc->move(room_a);
		tid=(string)TERMD->term_create(leader->query_name());
		TERMD->add_termer(tid,mate->query_name(),mate->query_name_cn());
		TERMD->add_termer(tid,away->query_name(),away->query_name_cn());
		npc->term_who_fight_npc=tid;
		npc->who_fight_npc=leader->query_name();
		npc->enemy=leader;
		npc->targets[leader]=1;
		away_before=total_exp(away);
		npc->fight_die();
		away_after=total_exp(away);
	};
	check("跨房间同队成员按全份额分享击杀经验",
		!err && away_after>away_before,
		err ? describe_error(err) :
			sprintf("away exp %d -> %d",away_before,away_after));
	cleanup_team(tid,leader ? leader->query_name() : "");
	destroy_test_player(leader);
	destroy_test_player(mate);
	destroy_test_player(away);
	if(npc)
		destruct(npc);
	if(room_a)
		destruct(room_a);
	if(room_b)
		destruct(room_b);
}

void test_distributed_team_exp_apply()
{
	object leader=create_test_player("__testunit_dexp_leader__");
	object member=create_test_player("__testunit_dexp_member__");
	object outsider=create_test_player("__testunit_dexp_outsider__");
	string tid="";
	int member_before=0;
	int member_after=0;
	mapping grant=([]);
	mapping skip=([]);
	mapping bad=([]);
	mixed err=catch{
		tid=(string)TERMD->term_create(leader->query_name());
		TERMD->add_termer(tid,member->query_name(),
			member->query_name_cn());
		member_before=total_exp(member);
		grant=TERMD->apply_distributed_team_exp(tid,500,18,
			leader->query_name(),({member->query_name()}));
		member_after=total_exp(member);
		skip=TERMD->apply_distributed_team_exp(tid,500,18,
			leader->query_name(),({outsider->query_name()}));
		bad=TERMD->apply_distributed_team_exp(tid,0,18,
			leader->query_name(),({member->query_name()}));
	};
	check("跨Worker经验事件按真实等级发放且非队员与坏参数被拒",
		!err && (int)grant["ok"] && (int)grant["granted"]==1 &&
		member_after>member_before &&
		(int)skip["granted"]==0 &&
		(string)bad["code"]=="invalid_team_exp",
		err ? describe_error(err) :
			sprintf("grant=%O skip=%O bad=%O exp %d -> %d",
				grant,skip,bad,member_before,member_after));
	cleanup_team(tid,leader ? leader->query_name() : "");
	destroy_test_player(leader);
	destroy_test_player(member);
	destroy_test_player(outsider);
}

void test_source_contract()
{
	string source=Stdio.read_file(ROOT+"/gamelib/inherit/npc.pike") || "";
	check("死亡路径保留单人结算回退且不再无条件吞掉击杀",
		search(source,"fight_die_single(env,credited_killer);")!=-1 &&
		search(source,"void fight_die_single(object env,"
			"void|object credited_killer)")!=-1 &&
		search(source,"//fight_die_single();//团队突然解散，谁也不给")==-1,
		"队伍解散/击杀者退队时整场击杀仍可能颗粒无收");
	check("异地队友经验经社交事件管线送达且白名单放行",
		search(source,"stage_local_social_event(\"team_exp\"")!=-1 &&
		search(Stdio.read_file(ROOT+
			"/gamelib/single/daemons/map_workerd.pike") || "",
			"\"team_exp\"")!=-1 &&
		search(Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike") ||
			"","apply_distributed_team_exp")!=-1 &&
		search(Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/pike_gateway.pike") ||
			"","\"team_exp\"")!=-1,
		"跨Worker队友分享经验缺失任一环节都不会送达");
	check("队伍界面为队友渲染静态房间传送入口",
		search(Stdio.read_file(ROOT+"/gamelib/cmds/my_term.pike") || "",
			"qge74hye")!=-1 &&
		search(Stdio.read_file(ROOT+"/gamelib/cmds/my_term.pike") || "",
			"query_map_worker_cluster_online_users")!=-1 &&
		search(Stdio.read_file(ROOT+"/gamelib/cmds/my_term.pike") || "",
			"qqlist_static_room_link_path")!=-1,
		"队伍页缺少跨Worker安全的队友传送入口");
}

void test_team_snapshot_republish_repair()
{
	object leader=create_test_player("__testunit_repub_leader__");
	object member=create_test_player("__testunit_repub_member__");
	string tid="";
	mapping found=([]);
	mapping missing=([]);
	string rpc_source="";
	string gateway_source="";
	mixed err=catch{
		tid=(string)TERMD->term_create(leader->query_name());
		TERMD->add_termer(tid,member->query_name(),
			member->query_name_cn());
		// 单进程测试无worker角色：能走到not_worker即证明队伍与队长
		// 查找全部命中，真实worker上该路径会重发权威快照。
		found=TERMD->republish_distributed_team_snapshot(tid);
		missing=TERMD->republish_distributed_team_snapshot(
			"bogus"+(string)time());
	};
	rpc_source=Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike") ||
		"";
	gateway_source=Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/pike_gateway.pike") || "";
	check("快照缺失拒绝触发源Worker重发权威快照(含冷却)",
		!err && (string)found["code"]=="not_worker" &&
		(string)missing["code"]=="team_not_found" &&
		search(rpc_source,"local_team_snapshot_republish")!=-1 &&
		search(rpc_source,"republish_distributed_team_snapshot")!=-1 &&
		search(gateway_source,
			"pike_gateway_request_team_snapshot_republish")!=-1 &&
		search(gateway_source,"team_snapshot_missing")!=-1 &&
		search(gateway_source,"local_team_snapshot_republish")!=-1 &&
		search(gateway_source,"pike_gateway_social_republish_at")!=-1,
		err ? describe_error(err) :
			sprintf("found=%O missing=%O",found,missing));
	cleanup_team(tid,leader ? leader->query_name() : "");
	destroy_test_player(leader);
	destroy_test_player(member);
}

int main()
{
	werror("\n========== 组队击杀归属测试 ==========\n");
	test_source_contract();
	test_killer_outside_recorded_team();
	test_disbanded_team_still_credits_killer();
	test_cross_room_member_shares_exp();
	test_distributed_team_exp_apply();
	test_team_snapshot_republish_repair();
	werror("组队击杀归属：总计%d，通过%d，失败%d\n",results["total"],
		results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
