#!/usr/bin/env pike
/** team_snapshot_missing修复回归：本地有队员但termMain缺快照时
 * 三条社交事件路径（chat/exp/notice）不再永久拒绝。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[快照重建] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[快照重建] ✗ %s: %s\n",name,detail);
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

void destroy_test_player(object|zero player)
{
	if(player)
		destruct(player);
}

int total_exp(object player)
{
	return (int)player->exp+(int)player->current_exp;
}

void cleanup_team(string tid,string leader_id)
{
	if(tid!="" && sizeof(tid)>1 && leader_id!="" &&
	   TERMD->query_termId(tid))
		TERMD->destory_term(tid,leader_id);
}

void test_chat_snapshot_rebuild()
{
	object leader=create_test_player("__testunit_rebuild_leader__");
	object follower=create_test_player("__testunit_rebuild_follower__");
	string tid="";
	mapping applied=([]);
	mapping members=([]);
	mixed err=catch{
		tid=(string)TERMD->term_create(leader->query_name());
		// 只写玩家侧term字段，不动termMain：模拟接收Worker丢失
		// 该队员快照条目（生产team_snapshot_missing的形态）。
		follower->set_term(tid);
		applied=TERMD->apply_distributed_team_chat(tid,
			"snapshot rebuild chat test",follower->query_name());
		members=TERMD->query_term_m(tid);
	};
	check("快照缺失时队伍聊天从本地玩家重建后放行",
		!err && (int)applied["ok"]==1,
		err ? describe_error(err) : sprintf("applied=%O",applied));
	check("重建把缺失队员与发送者写回termMain",
		mappingp(members) && members[follower->query_name()] &&
		sizeof(members[follower->query_name()])>=2,
		sprintf("members=%O",members));
	if(follower)
		follower->set_term("noterm");
	cleanup_team(tid,leader ? leader->query_name() : "");
	destroy_test_player(leader);
	destroy_test_player(follower);
}

void test_exp_snapshot_bypass()
{
	object leader=create_test_player("__testunit_rebexp_leader__");
	object follower=create_test_player("__testunit_rebexp_follower__");
	object outsider=create_test_player("__testunit_rebexp_outsider__");
	string tid="";
	int follower_before=0;
	int follower_after=0;
	mapping grant=([]);
	mapping skip=([]);
	mixed err=catch{
		tid=(string)TERMD->term_create(leader->query_name());
		follower->set_term(tid);
		follower_before=total_exp(follower);
		grant=TERMD->apply_distributed_team_exp(tid,500,18,
			follower->query_name(),({follower->query_name()}));
		follower_after=total_exp(follower);
		// 门禁跳过后逐人循环是唯一防线：非本队玩家必须仍拿不到经验。
		skip=TERMD->apply_distributed_team_exp(tid,500,18,
			follower->query_name(),({outsider->query_name()}));
	};
	check("快照缺失时跨Worker经验按逐人term校验发放",
		!err && (int)grant["ok"]==1 && (int)grant["granted"]==1 &&
		follower_after>follower_before,
		err ? describe_error(err) :
			sprintf("grant=%O exp %d -> %d",
				grant,follower_before,follower_after));
	check("门禁跳过后非本队目标仍零发放",
		!err && (int)skip["granted"]==0,
		sprintf("skip=%O",skip));
	if(follower)
		follower->set_term("noterm");
	cleanup_team(tid,leader ? leader->query_name() : "");
	destroy_test_player(leader);
	destroy_test_player(follower);
	destroy_test_player(outsider);
}

void test_notice_snapshot_rebuild()
{
	object leader=create_test_player("__testunit_rebntc_leader__");
	object follower=create_test_player("__testunit_rebntc_follower__");
	string tid="";
	mapping rebuilt=([]);
	mapping normal=([]);
	mixed err=catch{
		tid=(string)TERMD->term_create(leader->query_name());
		follower->set_term(tid);
		// 快照缺失路径：直接对本地队员tell_object并确认。
		rebuilt=TERMD->apply_distributed_team_notice(tid,
			"snapshot rebuild notice test",follower->query_name());
		// 快照在位路径：队长发言仍走term_tell原链路。
		normal=TERMD->apply_distributed_team_notice(tid,
			"normal notice test",leader->query_name());
	};
	check("快照缺失时队伍通知重建直发不拒绝",
		!err && (int)rebuilt["ok"]==1 && (int)rebuilt["rebuilt"]==1,
		err ? describe_error(err) :
			sprintf("rebuilt=%O",rebuilt));
	check("快照在位时通知仍走原有term_tell链路",
		!err && (int)normal["ok"]==1 && !normal["rebuilt"],
		sprintf("normal=%O",normal));
	if(follower)
		follower->set_term("noterm");
	cleanup_team(tid,leader ? leader->query_name() : "");
	destroy_test_player(leader);
	destroy_test_player(follower);
}

array(int) search_all(string source,string needle)
{
	array(int) positions=({});
	int pos=0;
	while((pos=search(source,needle,pos))!=-1){
		positions += ({pos});
		pos += sizeof(needle);
	}
	return positions;
}

void test_source_contract()
{
	string source=Stdio.read_file(
		ROOT+"/gamelib/single/daemons/termd.pike") || "";
	check("三条路径都接入本地玩家重建助手",
		search(source,"local_team_member_ids_from_players")!=-1 &&
		sizeof(search_all(source,"local_team_member_ids_from_players"))>=3,
		"任一路径回退为硬拒绝都会重现team_snapshot_missing");
	check("chat重建为发送者补占位条目",
		search(source,"({sender_id,\"member\",\"\",1})")!=-1,
		"远端发送者无本地对象时can_read_term仍会拒绝");
}

int main()
{
	werror("\n========== 队伍快照重建测试 ==========\n");
	test_source_contract();
	test_chat_snapshot_rebuild();
	test_exp_snapshot_bypass();
	test_notice_snapshot_rebuild();
	werror("队伍快照重建：总计%d，通过%d，失败%d\n",results["total"],
		results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
