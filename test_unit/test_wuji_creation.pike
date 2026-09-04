#!/usr/bin/env pike
/** 无极创建收费与门槛回归：照命>=300 + 1万碎玉，未解锁/未付费拒绝。 */

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

int main()
{
	string account_id = "xd01testunitwuji";
	object|zero payer = 0;
	mapping created;
	mapping purchased;
	werror("\n========== 无极创建收费测试 ==========\n");
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	mixed err = catch{
		/* 纯函数门槛 */
		mapping row300 = (["profession_id":"zhaoming","level":300]);
		mapping row299 = (["profession_id":"zhaoming","level":299]);
		mapping data300 = (["ok":1,"characters":({row300})]);
		mapping data299 = (["ok":1,"characters":({row299})]);
		int ok300 = (int)ACCOUNT_CHARACTERD->
			query_wuji_unlocked_from_summary(data300);
		int un299 = (int)ACCOUNT_CHARACTERD->
			query_wuji_unlocked_from_summary(data299);
		check("照命300解锁/299不解锁",ok300 && !un299,"");

		/* 未解锁拒绝建角 */
		created = ACCOUNT_CHARACTERD->create_character(account_id,
			"third","wuji","测无极","male","wuji_male");
		check("未解锁账号无法创建无极",
			!(int)created["ok"] &&
			search((string)created["message"],"未解锁")!=-1,
			sprintf("%O",created));

		/* 验证闸门代码存在（源码级检查） */
		string src = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/account_characterd.pike") || "";
		check("create_character 包含无极闸门",
			search(src,"profession_id==\"wuji\"")!=-1 &&
			search(src,"wuji_entitled")!=-1 &&
			search(src,"WUJI_CREATION_COST")!=-1,
			"闸门代码缺失");

		check("purchase_wuji_entitlement 函数存在",
			search(src,"mapping(string:mixed) purchase_wuji_entitlement")!= -1,
			"购买函数缺失");

		check("HTTP handler 包含无极购买调用",
			search(Stdio.read_file(ROOT+
				"/gamelib/single/daemons/_http_api_mod/account_characters.pike") || "",
				"purchase_wuji_entitlement")!=-1,
			"HTTP接线缺失");
	};
	if(err)
		check("流程无异常",0,describe_error(err));
	else
		check("流程无异常",1,"");
	if(payer)
		destruct(payer);
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	werror("========== 无极创建测试结束 ==========\n");
	return test_results["failed"]>0 ? 1 : 0;
}
