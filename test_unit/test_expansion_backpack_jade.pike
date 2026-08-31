#!/usr/bin/env pike
/** 扩充类购买（在线上限/人物位）兼容背包实体玉的支付回归：
 * 默认优先扣账号共享碎玉，不足用付款人物背包玉补足，失败全额回退。 */

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

string wallet_file(string account_id)
{
	return DATA_ROOT+"accounts/"+
		account_id[sizeof(account_id)-2..]+"/"+
		account_id+".wallet.json";
}

void dump_wallet_state(string tag,string account_id,object payer)
{
	mapping wallet = ACCOUNT_WALLETD->query_account_wallet(account_id);
	string raw = Stdio.read_file(wallet_file(account_id)) || "";
	werror("  [diag %s] wallet=%O raw=%.300s player_balance=%d\n",
		tag,wallet,raw,ACCOUNT_WALLETD->query_balance(payer));
}

void cleanup_player(string userid)
{
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_saved_player(string userid,string password)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->set_password(password);
	player->set_project("gamelib");
	player->set_userip("testunit-expansion");
	player->name_cn = "扩充支付测试人物";
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->save_with_result();
	return player;
}

void give_physical_yushi(object player,int amount)
{
	object yushi = clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
	yushi->amount = amount;
	yushi->move(player);
}

int main()
{
	string account_id = "xd01testunitexjade";
	string password = "testunit88";
	string request_id;
	object|zero payer = 0;
	int wallet_before;
	int physical_before;
	mapping payment;
	string config_backup = "";
	int config_touched = 0;
	werror("\n========== 扩充购买背包玉支付测试 ==========\n");
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	mixed err = catch{
		payer = create_saved_player(account_id,password);
		/* 钱包/账号归属解析依赖真实账号索引，先注册再走支付。 */
		mapping registered = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi");
		check("测试账号索引就绪",(int)registered["ok"],
			(string)(registered["message"] || "索引创建失败"));

		/* 1. 钱包足够：默认全扣共享余额。 */
		/* credit_recharge_once 入参是费用(元)，入账碎玉=fee×10。 */
		ACCOUNT_WALLETD->credit_recharge_once(payer,50,
			"testunitadmin",ACCOUNT_WALLETD->new_recharge_request_id());
		request_id = ACCOUNT_WALLETD->new_recharge_request_id();
		give_physical_yushi(payer,300);
		payment = YUSHID->pay_account_expansion(payer,account_id,300,
			"testunit_expand",request_id);
		check("钱包足够时默认只扣共享余额",
			(int)payment["ok"] && (int)payment["paid_wallet"]==300 &&
			(int)payment["paid_physical"]==0 &&
			ACCOUNT_WALLETD->query_balance(payer)==200 &&
			YUSHID->query_physical_all_num(payer)==300,
			sprintf("支付结果:%O 余额:%d 背包玉:%d",
				payment,ACCOUNT_WALLETD->query_balance(payer),
				YUSHID->query_physical_all_num(payer)));

		/* 2. 钱包不足、背包玉补足。 */
		dump_wallet_state("before2",account_id,payer);
		request_id = ACCOUNT_WALLETD->new_recharge_request_id();
		payment = YUSHID->pay_account_expansion(payer,account_id,350,
			"testunit_expand",request_id);
		check("钱包不足时自动用背包玉补足",
			(int)payment["ok"] && (int)payment["paid_wallet"]==200 &&
			(int)payment["paid_physical"]==150 &&
			ACCOUNT_WALLETD->query_balance(payer)==0 &&
			YUSHID->query_physical_all_num(payer)==150,
			sprintf("支付结果:%O 余额:%d 背包玉:%d",
				payment,ACCOUNT_WALLETD->query_balance(payer),
				YUSHID->query_physical_all_num(payer)));

		/* 3. 两者相加仍不足：拒绝且分文不扣。 */
		wallet_before = ACCOUNT_WALLETD->query_balance(payer);
		physical_before = YUSHID->query_physical_all_num(payer);
		payment = YUSHID->pay_account_expansion(payer,account_id,
			100000,"testunit_expand",
			ACCOUNT_WALLETD->new_recharge_request_id());
		check("总额不足时拒绝且分文不扣",
			!(int)payment["ok"] &&
			ACCOUNT_WALLETD->query_balance(payer)==wallet_before &&
			YUSHID->query_physical_all_num(payer)==physical_before,
			sprintf("支付结果:%O",payment));

		/* 4. 退款：钱包按request_id回滚，实体玉按折合值发回。 */
		request_id = ACCOUNT_WALLETD->new_recharge_request_id();
		ACCOUNT_WALLETD->credit_recharge_once(payer,8,"testunitadmin",
			ACCOUNT_WALLETD->new_recharge_request_id());
		payment = YUSHID->pay_account_expansion(payer,account_id,200,
			"testunit_expand",request_id);
		int mixed_ok = (int)payment["ok"] &&
			(int)payment["paid_wallet"]==80 &&
			(int)payment["paid_physical"]==120;
		int refunded = YUSHID->refund_account_expansion(payer,
			account_id,80,120,"testunit_expand_refund",request_id);
		check("混合支付后全额退款",
			mixed_ok && refunded &&
			ACCOUNT_WALLETD->query_balance(payer)==80 &&
			YUSHID->query_physical_all_num(payer)==150,
			sprintf("支付:%O 退款:%d 余额:%d 背包玉:%d",
				payment,refunded,
				ACCOUNT_WALLETD->query_balance(payer),
				YUSHID->query_physical_all_num(payer)));

		/* 5. 在线上限购买端到端（背包玉补足路径）：
		 * TestUnit阶段无人在线，临时把在线基线降到2再恢复。 */
		ACCOUNT_WALLETD->remove_test_wallet(account_id);
		give_physical_yushi(payer,1000);
		config_backup = Stdio.read_file(
			ROOT+"/gamelib/etc/account_characters.conf") || "";
		config_touched = 1;
		Stdio.write_file(ROOT+"/gamelib/etc/account_characters.conf",
			"# testunit temp\nmax_online_characters=2\n");
		int capacity_before = ACCOUNT_CHARACTERD->
			query_account_online_capacity(account_id);
		int physical_before5 = YUSHID->query_physical_all_num(payer);
		mapping result = ACCOUNT_CHARACTERD->
			purchase_online_capacity_expansion(account_id,
			ACCOUNT_WALLETD->new_recharge_request_id(),payer);
		check("在线上限购买用背包玉补足并写扩容",
			(int)result["ok"] &&
			ACCOUNT_CHARACTERD->query_account_online_capacity(
				account_id)==capacity_before+1 &&
			YUSHID->query_physical_all_num(payer)==physical_before5-100,
			sprintf("结果:%O 扩容后:%d 背包玉:%d(期望%d)",
				result,
				ACCOUNT_CHARACTERD->query_account_online_capacity(
					account_id),
				YUSHID->query_physical_all_num(payer),
				physical_before5-100));

		/* 6. 不传payer保持旧的纯余额行为。 */
		result = ACCOUNT_CHARACTERD->
			purchase_online_capacity_expansion(account_id,
			ACCOUNT_WALLETD->new_recharge_request_id());
		check("无payer时保持纯余额扣款语义",
			!(int)result["ok"] &&
			String.trim_all_whites((string)result["message"])!="",
			sprintf("结果:%O",result));
		if(config_backup!="")
			Stdio.write_file(ROOT+"/gamelib/etc/account_characters.conf",
				config_backup);
	};
	if(err)
		check("扩充背包玉支付流程无异常",0,describe_error(err));
	else
		check("扩充背包玉支付流程无异常",1,"");
	if(config_touched && config_backup!="")
		Stdio.write_file(ROOT+"/gamelib/etc/account_characters.conf",
			config_backup);
	if(payer)
		destruct(payer);
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	werror("========== 扩充购买背包玉测试结束 ==========\n");
	return test_results["failed"]>0 ? 1 : 0;
}
