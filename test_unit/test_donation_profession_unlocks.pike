#!/usr/bin/env pike
/** 共享账号累计真实捐赠解锁无相/太极创建资格回归。 */

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

string player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

void cleanup_player(string userid)
{
	// 只允许清理本用例的固定夹具，避免未来重构参数时误删真实档案。
	if(!userid || !has_prefix(userid,"xd99testunitdonation"))
		return;
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_root(string account_id)
{
	object player = clone(GAMELIB_USER);
	player->set_name(account_id);
	player->set_password("testunit88");
	player->set_project("gamelib");
	player->name_cn = "捐赠职业解锁测试";
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level = 1;
	player->set_att_by_level();
	player->save_with_result();
	return player;
}

int finish_character(mapping created,string race_id,string profession_id)
{
	if(!(int)created["ok"] || !mappingp(created["character"]))
		return 0;
	string character_id = (string)created["character"]["id"];
	object player = clone(GAMELIB_USER);
	player->set_name(character_id);
	player->set_project("gamelib");
	if(!player->restore()){
		destruct(player);
		return 0;
	}
	player->name_cn = "捐赠解锁"+profession_id;
	player->set_raceId(race_id);
	player->set_profeId(profession_id);
	player->setup_player(race_id,profession_id);
	int saved = player->save_with_result();
	destruct(player);
	return saved;
}

int main()
{
	string account_id = "xd99testunitdonationunlock";
	string legacy_id = "xd99testunitdonationlegacy";
	object|zero root = 0;
	object|zero legacy = 0;
	werror("\n========== 捐赠隐藏职业解锁测试 ==========\n");
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	ACCOUNT_WALLETD->remove_test_wallet(legacy_id);
	ACCOUNT_CHARACTERD->remove_test_account(legacy_id);
	cleanup_player(legacy_id);
	mixed err = catch{
		root = create_root(account_id);
		mapping below = ACCOUNT_WALLETD->credit_recharge_once(root,2999,
			"testunit",ACCOUNT_WALLETD->new_recharge_request_id());
		mapping below_status = ACCOUNT_CHARACTERD->query_account_characters(
			account_id);
		check("2999元不会提前解锁无相或太极",
			below["ok"] && !(int)below_status["wuxiang_unlocked"] &&
			!(int)below_status["taiji_unlocked"],
			"捐赠职业门槛出现越界开放");

		mapping exact_wuxiang = ACCOUNT_WALLETD->credit_recharge_once(root,1,
			"testunit",ACCOUNT_WALLETD->new_recharge_request_id());
		mapping wuxiang_status = ACCOUNT_CHARACTERD->query_account_characters(
			account_id);
		mapping made_wuxiang = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","wuxiang");
		int wuxiang_finished = finish_character(made_wuxiang,
			"third","wuxiang");
		check("累计3000元只解锁无相且可真实创建",
			exact_wuxiang["ok"] &&
			(int)wuxiang_status["donation_total"]==3000 &&
			(int)wuxiang_status["wuxiang_unlocked"] &&
			!(int)wuxiang_status["taiji_unlocked"] &&
			(int)made_wuxiang["ok"] &&
			made_wuxiang["unlock_source"]=="donation" && wuxiang_finished,
			(string)(made_wuxiang["message"] || "3000元创建无相失败"));

		mapping below_taiji = ACCOUNT_WALLETD->credit_recharge_once(root,6999,
			"testunit",ACCOUNT_WALLETD->new_recharge_request_id());
		mapping below_taiji_status =
			ACCOUNT_CHARACTERD->query_account_characters(account_id);
		check("累计9999元仍不会提前解锁太极",
			below_taiji["ok"] &&
			(int)below_taiji_status["donation_total"]==9999 &&
			(int)below_taiji_status["wuxiang_unlocked"] &&
			!(int)below_taiji_status["taiji_unlocked"],
			"太极捐赠门槛少于10000元");

		mapping exact_taiji = ACCOUNT_WALLETD->credit_recharge_once(root,1,
			"testunit",ACCOUNT_WALLETD->new_recharge_request_id());
		mapping taiji_status = ACCOUNT_CHARACTERD->query_account_characters(
			account_id);
		mapping made_taiji = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","taiji");
		check("累计10000元解锁太极且保留无相资格",
			exact_taiji["ok"] &&
			(int)taiji_status["donation_total"]==10000 &&
			(int)taiji_status["wuxiang_unlocked"] &&
			(int)taiji_status["taiji_unlocked"] &&
			(int)made_taiji["ok"] &&
			made_taiji["unlock_source"]=="donation",
			(string)(made_taiji["message"] || "10000元创建太极失败"));

		legacy = create_root(legacy_id);
		legacy->set_all_fee(10000);
		legacy->save_with_result();
		ACCOUNT_WALLETD->drop_test_cache(legacy_id);
		mapping legacy_status = ACCOUNT_CHARACTERD->query_account_characters(
			legacy_id);
		check("共享钱包上线前的老all_fee同样解锁两种职业",
			(int)legacy_status["donation_total"]==10000 &&
			(int)legacy_status["wuxiang_unlocked"] &&
			(int)legacy_status["taiji_unlocked"],
			"历史捐赠未纳入账号级职业资格");

		string audit = Stdio.read_file(ROOT+
			"/log/hidden_profession_unlock.log") || "";
		check("捐赠解锁创建写入账号、职业、门槛审计日志",
			search(audit,"account="+account_id)!=-1 &&
			search(audit,"profession=wuxiang source=donation")!=-1 &&
			search(audit,"profession=taiji source=donation")!=-1,
			"隐藏职业捐赠创建缺少审计凭证");
	};
	if(err)
		check("捐赠隐藏职业测试没有运行异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(root)
		destruct(root);
	if(legacy)
		destruct(legacy);
	array(string) ids = ACCOUNT_CHARACTERD->query_character_ids(account_id);
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	foreach(ids,string character_id)
		cleanup_player(character_id);
	cleanup_player(account_id);
	ACCOUNT_WALLETD->remove_test_wallet(legacy_id);
	ACCOUNT_CHARACTERD->remove_test_account(legacy_id);
	cleanup_player(legacy_id);
	werror("捐赠隐藏职业解锁：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
