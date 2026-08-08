#!/usr/bin/env pike
/** 多职业注册账号共享充值钱包、幂等入账与混合支付回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);
array(int) concurrent_debit_results = ({});
Thread.Mutex concurrent_result_lock = Thread.Mutex();

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

string account_file(string account_id)
{
	return DATA_ROOT+"accounts/"+
		account_id[sizeof(account_id)-2..]+"/"+
		account_id+".json";
}

void cleanup_player(string userid)
{
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_saved_player(string userid,string password,string race_id,
	string profession_id)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->set_password(password);
	player->set_project("gamelib");
	player->set_userip("testunit-wallet");
	player->name_cn = "共享充值测试人物";
	player->set_raceId(race_id);
	player->set_profeId(profession_id);
	player->setup_player(race_id,profession_id);
	player->save_with_result();
	return player;
}

void give_physical_yushi(object player,int amount)
{
	object yushi = clone(ROOT+"/gamelib/clone/item/yushi/suiyu");
	yushi->amount = amount;
	yushi->move(player);
}

void run_concurrent_debit(object player,int amount)
{
	int result = ACCOUNT_WALLETD->debit_recharge(
		player,amount,"testunit_concurrent_purchase");
	object key = concurrent_result_lock->lock();
	concurrent_debit_results += ({result});
	destruct(key);
}

int main()
{
	string account_id = "xd01testunitwallet";
	string password = "testunit88";
	string child_id = "";
	string request_id = ACCOUNT_WALLETD->new_recharge_request_id();
	string wallet_path = wallet_file(account_id);
	string valid_wallet = "";
	object|zero root_player = 0;
	object|zero child_player = 0;
	object original_player = this_player();
	werror("\n========== 多职业账号共享充值钱包测试 ==========\n");
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	mixed err = catch{
		root_player = create_saved_player(account_id,password,
			"human","jianxian");
		root_player->set_all_fee(200);
		root_player->save_with_result();
		check("旧单人物账号无需预先存在分职业索引",
			Stdio.file_size(account_file(account_id))<=0 &&
			root_player->query_donation_exp_multiplier()==2,
			"旧人物在账号索引迁移前无法保留历史捐赠权益");
		mapping created = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi");
		if(created["ok"])
			child_id = (string)created["character"]["id"];
		check("测试注册账号建立两个独立职业人物",
			created["ok"] && child_id!="",
			(string)(created["message"] || "子人物创建失败"));

		child_player = clone(GAMELIB_USER);
		child_player->set_name(child_id);
		child_player->set_project("gamelib");
		child_player->restore();
		child_player->name_cn = "共享充值方士";
		child_player->set_raceId("third");
		child_player->set_profeId("fangshi");
		child_player->setup_player("third","fangshi");
		child_player->save_with_result();
		int empty_balance = ACCOUNT_WALLETD->query_balance(root_player);
		check("老账号查询和人物管理不会提前创建钱包文件",
			empty_balance==0 && Stdio.file_size(wallet_path)<=0,
			"只读兼容路径写入了共享钱包文件");
		child_player->set_all_fee(0);
		ACCOUNT_WALLETD->drop_test_cache(account_id);
		check("无共享钱包文件的老账号也继承主人物历史捐赠倍数",
			child_player->query_donation_exp_multiplier()==2 &&
			Stdio.file_size(wallet_path)<=0,
			"副职业没有读取账号内旧人物的历史累计捐赠");

		int raw_before = YUSHID->query_physical_all_num(root_player);
		mixed raw_err = catch{
			set_this_player(root_player);
			((object)(ROOT+"/gamelib/cmds/yushi_add_fee.pike"))->
				main("100 5 szx");
			((object)(ROOT+"/gamelib/cmds/txadd.pike"))->main(
				child_id+" 50 "+ACCOUNT_WALLETD->
				new_recharge_request_id());
		};
		if(original_player)
			set_this_player(original_player);
		else
			set_this_player(this_object());
		check("普通人物不能调用旧铸币或管理员共享充值命令",
			!raw_err &&
			YUSHID->query_physical_all_num(root_player)==raw_before &&
			Stdio.file_size(wallet_path)<=0,
			"非管理员命令改变了人物或账号余额");

		give_physical_yushi(root_player,7);
		mapping credited = ACCOUNT_WALLETD->credit_recharge_once(
			child_player,50,"testunitadmin",request_id);
		check("从任一职业充值都进入注册账号共享余额",
			credited["ok"] && !credited["duplicate"] &&
			credited["account_id"]==account_id &&
			credited["balance"]==500 &&
			ACCOUNT_WALLETD->query_balance(root_player)==500 &&
			ACCOUNT_WALLETD->query_balance(child_player)==500,
			"充值余额没有按注册账号共享");

		mapping duplicate = ACCOUNT_WALLETD->credit_recharge_once(
			child_player,50,"testunitadmin",request_id);
		mapping conflict = ACCOUNT_WALLETD->credit_recharge_once(
			child_player,51,"testunitadmin",request_id);
		string expired_id = sprintf("%010d",1)+
			String.string2hex(Crypto.Random.random_string(27));
		mapping expired = ACCOUNT_WALLETD->credit_recharge_once(
			child_player,50,"testunitadmin",expired_id);
		check("重复确认幂等且冲突、过期请求失败关闭",
			duplicate["ok"] && duplicate["duplicate"] &&
			!conflict["ok"] && !expired["ok"] &&
			ACCOUNT_WALLETD->query_balance(root_player)==500,
			"重复点击造成重复入账或请求编号被复用");

		check("历史人物玉石不迁移也不复制给其他职业",
			YUSHID->query_physical_all_num(root_player)==7 &&
			YUSHID->query_physical_all_num(child_player)==0 &&
			YUSHID->query_all_num(root_player)==507 &&
			YUSHID->query_all_num(child_player)==500,
			"人物玉石和共享充值余额边界错误");

		int child_paid = YUSHID->pay_yushi(child_player,120);
		int root_paid = YUSHID->pay_yushi(root_player,10);
		int child_payment_saved=child_player->save_with_result();
		int root_payment_saved=root_player->save_with_result();
		int child_payment_finalized=YUSHID->
			complete_wallet_payment_player_save(child_player);
		int root_payment_finalized=YUSHID->
			complete_wallet_payment_player_save(root_player);
		if(child_payment_finalized)
			child_player->save_with_result();
		if(root_payment_finalized)
			root_player->save_with_result();
		check("两个职业消费同一余额且人物玉石优先混合扣除",
			child_paid && root_paid && child_payment_saved &&
			root_payment_saved && child_payment_finalized &&
			root_payment_finalized &&
			ACCOUNT_WALLETD->query_balance(root_player)==377 &&
			ACCOUNT_WALLETD->query_balance(child_player)==377 &&
			YUSHID->query_physical_all_num(root_player)==0 &&
			!sizeof(child_player["/plus/yushi_wallet_payment"] || ([])) &&
			!sizeof(root_player["/plus/yushi_wallet_payment"] || ([])),
			"共享扣款、串行余额或混合支付错误");

		give_physical_yushi(child_player,11);
		check("任务和赠送玉石继续归领取人物独立持有",
			YUSHID->query_all_num(child_player)==388 &&
			YUSHID->query_all_num(root_player)==377,
			"免费玉石错误进入共享钱包");

		int root_reconciled = ACCOUNT_WALLETD->
			reconcile_player_login(root_player);
		child_player->set_all_fee(0);
		check("账号累计捐赠直接决定所有职业的打怪经验倍数",
			child_player->query_donation_exp_multiplier()==2,
			"子职业仍只读取自己人物档案中的累计捐赠");
		check("累计充值权益同步到在线职业并在其他职业登录时对账",
			root_reconciled && root_player->query_all_fee()==250,
			"账号累计充值权益没有同步");

		mapping wallet = ACCOUNT_WALLETD->query_wallet(root_player);
		array transactions = wallet["transactions"];
		check("充值和两个职业消费均有持久化审计流水",
			wallet["ok"] && wallet["revision"]==3 &&
			sizeof(transactions)==3 &&
			sizeof((mapping)wallet["debit_requests"])==0 &&
			transactions[0]["type"]=="recharge" &&
			transactions[1]["type"]=="spend" &&
			transactions[2]["type"]=="spend",
			"钱包流水或修订号不完整");

		string debit_request=ACCOUNT_WALLETD->new_recharge_request_id();
		mapping debit_first=ACCOUNT_WALLETD->debit_recharge_once(
			child_player,50,"testunit_idempotent",debit_request);
		mapping debit_duplicate=ACCOUNT_WALLETD->debit_recharge_once(
			child_player,50,"testunit_idempotent",debit_request);
		int rollback_first=ACCOUNT_WALLETD->rollback_debit_recharge_once(
			child_player,debit_request,"testunit_idempotent_rollback");
		int rollback_duplicate=ACCOUNT_WALLETD->rollback_debit_recharge_once(
			child_player,debit_request,"testunit_idempotent_rollback");
		check("跨存档共享钱包扣款可重试且回滚只执行一次",
			debit_first["ok"] && !debit_first["duplicate"] &&
			debit_duplicate["ok"] && debit_duplicate["duplicate"] &&
			rollback_first && rollback_duplicate &&
			ACCOUNT_WALLETD->query_balance(root_player)==377,
			"幂等扣款发生重复扣除或重复退款");

		string pay_request=ACCOUNT_WALLETD->new_recharge_request_id();
		int pay_first=YUSHID->pay_yushi_once(child_player,20,pay_request);
		// 模拟共享钱包已落盘、人物档案仍是扣款前状态的进程退出。
		give_physical_yushi(child_player,11);
		int pay_recovered=YUSHID->pay_yushi_once(
			child_player,20,pay_request);
		int pay_rolled_back=ACCOUNT_WALLETD->rollback_debit_recharge_once(
			child_player,pay_request,"testunit_payment_rollback");
		check("人物存档退出重试不会重复扣除共享钱包",
			pay_first && pay_recovered && pay_rolled_back &&
			YUSHID->query_physical_all_num(child_player)==0 &&
			ACCOUNT_WALLETD->query_balance(root_player)==377,
			"人物与钱包跨存档恢复发生双扣或少扣");

		string crash_request=ACCOUNT_WALLETD->new_recharge_request_id();
		child_player["/plus/yushi_wallet_payment"]=(
			["phase":"prepared","request_id":crash_request,
			 "wallet_amount":10,"total_amount":10,
			 "created_at":time()]);
		int crash_marker_saved=child_player->save_with_result();
		mapping crash_debit=ACCOUNT_WALLETD->debit_recharge_once(
			child_player,10,"yushi_purchase",crash_request);
		int crash_recovered=YUSHID->reconcile_wallet_payment(child_player);
		check("钱包已扣而人物奖励未落盘的退出窗口自动退款",
			crash_marker_saved && crash_debit["ok"] && crash_recovered &&
			ACCOUNT_WALLETD->query_balance(root_player)==377 &&
			!sizeof(child_player["/plus/yushi_wallet_payment"] || ([])),
			"prepared 恢复凭据没有回滚共享钱包扣款");

		concurrent_debit_results = ({});
		object debit_one = Thread.Thread(run_concurrent_debit,
			root_player,200);
		object debit_two = Thread.Thread(run_concurrent_debit,
			child_player,200);
		debit_one->wait();
		debit_two->wait();
		int debit_successes = 0;
		foreach(concurrent_debit_results,int one_debit)
			debit_successes += one_debit;
		int refunded = ACCOUNT_WALLETD->refund_recharge(
			root_player,200,"testunit_concurrent_restore");
		check("同账号两个职业并发扣款只能有一个消耗共享余额",
			sizeof(concurrent_debit_results)==2 &&
			debit_successes==1 && refunded &&
			ACCOUNT_WALLETD->query_balance(root_player)==377,
			"并发消费发生超扣、双扣或回滚失败");

		valid_wallet = Stdio.read_file(wallet_path) || "";
		Stdio.write_file(wallet_path,"{broken-wallet");
		ACCOUNT_WALLETD->drop_test_cache(account_id);
		mapping broken = ACCOUNT_WALLETD->query_wallet(root_player);
		mapping blocked_credit = ACCOUNT_WALLETD->credit_recharge(
			root_player,10,"testunitadmin");
		check("钱包损坏时不从旧备份复活余额并停止入账消费",
			!broken["ok"] && !blocked_credit["ok"] &&
			!ACCOUNT_WALLETD->debit_recharge(root_player,1,"test"),
			"损坏钱包仍可入账、消费或回退备份");
		check("钱包异常不会连带锁死人物登录",
			ACCOUNT_WALLETD->reconcile_player_login(root_player)==1,
			"共享钱包异常阻止了人物登录");
		Stdio.write_file(wallet_path,valid_wallet);
		ACCOUNT_WALLETD->drop_test_cache(account_id);
		check("修复有效主文件后共享余额恢复",
			ACCOUNT_WALLETD->query_balance(child_player)==377,
			"钱包修复后没有恢复正确余额");

		string txadd_source = Stdio.read_file(
			ROOT+"/gamelib/cmds/txadd.pike") || "";
		string legacy_source = Stdio.read_file(
			ROOT+"/gamelib/cmds/yushi_add_fee.pike") || "";
		string api_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/account_characters.pike") || "";
		string user_source = Stdio.read_file(ROOT+
			"/gamelib/clone/user.pike") || "";
		string yushid_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/yushid.pike") || "";
		string vue_source = Stdio.read_file(ROOT+
			"/vue_source/index.html") || "";
		check("管理充值有权限、二次确认、幂等钱包且旧铸币入口封闭",
			search(txadd_source,"MANAGERD->checkpower")!=-1 &&
			search(txadd_source,"credit_recharge_once")!=-1 &&
			search(txadd_source,"确认共享充值")!=-1 &&
			search(txadd_source,"player->command(\"yushi_add_fee") == -1 &&
			search(legacy_source,"MANAGERD->checkpower")!=-1,
			"充值入口仍存在越权、误点或直接铸币路径");
		check("人物管理平台明确返回并展示账号共享充值余额",
			search(api_source,"shared_recharge_balance")!=-1 &&
			search(vue_source,"注册账号共享充值余额")!=-1,
			"多职业平台没有向玩家说明余额归属");
		check("人物存档不跨账号索引与钱包锁清理凭据",
			search(user_source,"prepare_wallet_payment_player_save")!=-1 &&
			search(user_source,"complete_wallet_payment_player_save")==-1 &&
			search(yushid_source,
				"commit_wallet_payment_after_command")!=-1 &&
			search(yushid_source,
				"complete_wallet_payment_player_save(player)")!=-1,
			"任意存档路径仍可能形成 account-wallet-account 锁环");

		array(string) compile_paths = ({
			"/gamelib/single/daemons/account_walletd.pike",
			"/gamelib/single/daemons/yushid.pike",
			"/gamelib/cmds/txadd.pike",
			"/gamelib/cmds/yushi_add_fee.pike",
			"/gamelib/single/daemons/http_api_daemon.pike",
			"/lowlib/system/inherit/user.pike",
		});
		int compile_ok = 1;
		string compile_error = "";
		foreach(compile_paths,string path){
			mixed compile_err = catch{ compile_file(ROOT+path); };
			if(compile_err){
				compile_ok = 0;
				compile_error += path+":"+describe_error(compile_err)+" ";
			}
		}
		check("共享充值后端与HTTP人物平台通过真实Pike编译",
			compile_ok,compile_error);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("共享充值钱包测试运行时无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(root_player)
		destruct(root_player);
	if(child_player)
		destruct(child_player);
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	if(child_id!="")
		cleanup_player(child_id);
	werror("共享充值钱包测试完成：%d/%d 通过，%d 失败\n",
		test_results["passed"],test_results["total"],
		test_results["failed"]);
	return test_results["failed"] ? 1 : 0;
}
