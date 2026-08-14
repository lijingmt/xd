#!/usr/bin/env pike
/** 邀请注册、半年10%返玉与累计300元太古卷轴回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results=(["total":0,"passed":0,"failed":0]);

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

string player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

void cleanup_player(string userid)
{
	string path=player_file(userid);
	rm(path);rm(path+".tmp");rm(path+".bak");rm(path+".bak.tmp");
}

object create_saved_player(string userid,string userip)
{
	object player=clone(GAMELIB_USER);
	player->set_name(userid);
	player->set_password("testunit88");
	player->set_project("gamelib");
	player->set_userip(userip);
	player->name_cn="邀请系统测试人物";
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->save_with_result();
	return player;
}

int inventory_amount(object player,string item_name)
{
	int amount;
	foreach(all_inventory(player),object item)
		if(item && (string)item->query_name()==item_name)
			amount+=item->is("combine_item") ? (int)item->amount : 1;
	return amount;
}

int main()
{
	string inviter_id="xd01testunitReferrer";
	string lowercase_collision="xd01testunitreferrer";
	string invitee_one="xd01testunitreferreda";
	string invitee_two="xd01testunitreferredb";
	array(string) ids=({inviter_id,lowercase_collision,invitee_one,
		invitee_two});
	object|zero inviter=0;
	object|zero collision=0;
	object|zero first=0;
	object|zero second=0;
	int case_sensitive_filesystem=0;
	object original_player=this_player();
	werror("\n========== 邀请半年返玉与太古卷轴测试 ==========\n");
	REFERRALD->remove_test_referrals(ids);
	foreach(ids,string userid){
		ACCOUNT_WALLETD->remove_test_wallet(userid);
		ACCOUNT_CHARACTERD->remove_test_account(userid);
		cleanup_player(userid);
	}
	mixed err=catch{
		inviter=create_saved_player(inviter_id,"198.51.100.10");
		case_sensitive_filesystem=
			Stdio.file_size(player_file(lowercase_collision))<=0;
		if(case_sensitive_filesystem)
			collision=create_saved_player(lowercase_collision,
				"198.51.100.13");
		first=create_saved_player(invitee_one,"198.51.100.11");
		second=create_saved_player(invitee_two,"198.51.100.12");
		mapping uppercase_validation=REFERRALD->
			validate_registration_invite(invitee_one,inviter_id,
				"198.51.100.11");
		mapping lowercase_validation=case_sensitive_filesystem ?
			REFERRALD->validate_registration_invite(invitee_one,
				lowercase_collision,"198.51.100.11") : ([]);
		check("邀请码严格保留大小写且不会串到同名小写账号",
			uppercase_validation["ok"] &&
			uppercase_validation["inviter_account"]==inviter_id &&
			(!case_sensitive_filesystem ||
			 (lowercase_validation["ok"] &&
			  lowercase_validation["inviter_account"]==lowercase_collision &&
			  uppercase_validation["inviter_account"]!=
				lowercase_validation["inviter_account"])),
			"LSQ与lsq未按精确人物档案解析");
		mapping self_bind=REFERRALD->bind_registration(inviter_id,
			inviter_id,"198.51.100.10");
		mapping same_network=REFERRALD->validate_registration_invite(invitee_one,
			inviter_id,"198.51.100.10");
		check("自邀被拒绝，同家庭/代理网络标记审计但不误伤",
			!self_bind["ok"] && same_network["ok"] &&
			same_network["registration_network_match"] &&
			!sizeof(REFERRALD->query_relation(invitee_one)),
			"self="+sprintf("%O",self_bind)+" network="+
				sprintf("%O",same_network)+" relation="+
				sprintf("%O",REFERRALD->query_relation(invitee_one)));
		mapping bound_one=REFERRALD->bind_registration(invitee_one,
			inviter_id,"198.51.100.11");
		mapping rebound=REFERRALD->bind_registration(invitee_one,
			invitee_two,"198.51.100.11");
		mapping bound_two=REFERRALD->bind_registration(invitee_two,
			inviter_id,"198.51.100.12");
		check("邀请关系按注册账号永久绑定且不能改绑",
			bound_one["ok"] && bound_two["ok"] && !rebound["ok"] &&
			REFERRALD->query_relation(invitee_one)["inviter_account"]==
				inviter_id,
			"关系缺失或可被第二邀请码覆盖");
		string relation_index=DATA_ROOT+"referrals/by_inviter/"+
			inviter_id[sizeof(inviter_id)-2..]+"/"+inviter_id+"/"+
			invitee_one+".json";
		rm(relation_index);
		mapping repaired=REFERRALD->query_relation(invitee_one);
		check("邀请统计索引缺失时由规范关系自动修复",
			repaired["inviter_account"]==inviter_id &&
			Stdio.file_size(relation_index)>0,
			"索引未重建，邀请人数可能漏计");
		check("180天奖励窗口首尾边界明确",
			REFERRALD->referral_reward_window_open(1000,1000) &&
			REFERRALD->referral_reward_window_open(1000,
				1000+180*24*3600-1) &&
			!REFERRALD->referral_reward_window_open(1000,
				1000+180*24*3600),
			"半年窗口存在一天或一秒偏差");
		string request_one=ACCOUNT_WALLETD->new_recharge_request_id();
		string request_two=ACCOUNT_WALLETD->new_recharge_request_id();
		mapping recharge_one=ACCOUNT_WALLETD->credit_recharge_once(first,
			100,"testunitadmin",request_one);
		mapping reward_one=REFERRALD->record_recharge_from_wallet(
			invitee_one,request_one);
		mapping reward_repeat=REFERRALD->record_recharge_from_wallet(
			invitee_one,request_one);
		mapping recharge_two=ACCOUNT_WALLETD->credit_recharge_once(second,
			200,"testunitadmin",request_two);
		mapping reward_two=REFERRALD->record_recharge_from_wallet(
			invitee_two,request_two);
		check("每笔真实充值自动返到账价值10%的永久共享仙玉",
			recharge_one["ok"] && recharge_two["ok"] &&
			reward_one["ok"] && reward_two["ok"] &&
			reward_one["reward_amount"]==100 &&
			reward_two["reward_amount"]==200 &&
			ACCOUNT_WALLETD->query_balance(inviter)==300,
			sprintf("one=%O two=%O balance=%d",reward_one,reward_two,
				ACCOUNT_WALLETD->query_balance(inviter)));
		check("同一管理员补单请求跨Worker重试不重复返玉或累计",
			reward_repeat["ok"] && reward_repeat["duplicate"] &&
			reward_repeat["credit_duplicate"] &&
			ACCOUNT_WALLETD->query_balance(inviter)==300,
			sprintf("repeat=%O balance=%d",reward_repeat,
				ACCOUNT_WALLETD->query_balance(inviter)));
		int before_scroll=inventory_amount(inviter,
			"ancient_skill_choice_token");
		mapping stats=REFERRALD->settle_and_query(inviter);
		mapping stats_repeat=REFERRALD->settle_and_query(inviter);
		check("多个直属账号累计有效捐赠每满300元只发一张绑定择卷",
			stats["ok"] && stats["invite_count"]==2 &&
			stats["donor_count"]==2 &&
			stats["eligible_recharge_fee"]==300 &&
			stats["scroll_earned"]==1 && stats["new_scrolls"]==1 &&
			inventory_amount(inviter,"ancient_skill_choice_token")==
				before_scroll+1 &&
			stats_repeat["new_scrolls"]==0 &&
			inventory_amount(inviter,"ancient_skill_choice_token")==
				before_scroll+1,
			sprintf("stats=%O repeat=%O",stats,stats_repeat));
	};
	if(err)
		check("邀请奖励测试无运行异常",0,describe_error(err));
	if(original_player)
		set_this_player(original_player);
	foreach(({inviter,collision,first,second}),object player)
		if(player)
			destruct(player);
	REFERRALD->remove_test_referrals(ids);
	foreach(ids,string userid){
		ACCOUNT_WALLETD->remove_test_wallet(userid);
		ACCOUNT_CHARACTERD->remove_test_account(userid);
		cleanup_player(userid);
	}
	werror("[TEST_REFERRAL_REWARDS] total=%d passed=%d failed=%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"] ? 1 : 0;
}
