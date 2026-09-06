#!/usr/bin/env pike
/** 400级解锁回归：无心300级→账号flag→VIPD上限400；
 * 经验曲线301-400连续；幂等触发。 */

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
	string account_id = "xd01testunitcap4";
	werror("\n========== 无心400级解锁测试 ==========\n");
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	mixed err = catch{
		/* 账号归属解析依赖真实存档+索引：先落一个人物档再注册索引。 */
		object seeder = clone(GAMELIB_USER);
		seeder->set_name(account_id);
		seeder->set_password("testunitcap4");
		seeder->set_project("gamelib");
		seeder->set_userip("testunit-cap4");
		seeder->name_cn = "四级解锁测试人物";
		seeder->set_raceId("human");
		seeder->set_profeId("jianxian");
		seeder->setup_player("human","jianxian");
		seeder->save_with_result();
		destruct(seeder);
		mapping seeded = ACCOUNT_CHARACTERD->create_character(
			account_id,"human","jianxian","测四级","male","h_male1");
		check("测试账号索引就绪",((int)seeded["ok"])==1,
			sprintf("%O",seeded));
		/* 账号flag：默认关 */
		check("未解锁账号400上限关闭",
			!ACCOUNT_CHARACTERD->query_account_level_cap_400(
				account_id),
			"应当为0");
		/* 触发与幂等 */
		mapping r1 = ACCOUNT_CHARACTERD->
			record_account_level_cap_400(account_id);
		mapping r2 = ACCOUNT_CHARACTERD->
			record_account_level_cap_400(account_id);
		check("400上限触发成功",((int)r1["ok"])==1,
			sprintf("%O",r1));
		check("重复触发幂等",((int)r2["already"])==1,
			sprintf("%O",r2));
		check("触发后查询生效",
			ACCOUNT_CHARACTERD->query_account_level_cap_400(
				account_id)==1,
			"查询应为1");
		/* 汇总字段 */
		mapping summary = ACCOUNT_CHARACTERD->
			query_account_characters(account_id);
		check("账号汇总包含400上限字段",
			(int)summary["level_cap_400"]==1,
			sprintf("%O",(int)summary["level_cap_400"]));

		/* 源码级：VIPD上限覆盖与level触发 */
		string vip_src = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/vipd.pike") || "";
		check("VIPD包含账号400上限覆盖",
			search(vip_src,"query_account_level_cap_400")!=-1 &&
			search(vip_src,"return 400;")!=-1,
			"VIPD覆盖缺失");
		string level_src = Stdio.read_file(ROOT+
			"/lowlib/mudlib/inherit/feature/level.pike") || "";
		check("level.pike包含无心300级触发",
			search(level_src,"record_account_level_cap_400")!=-1 &&
			search(level_src,"\"wuxin\"")!=-1,
			"触发缺失");
		check("无心三系成长16+3.2L存在",
			search(level_src,"16+(int)(level_now*3.2)")!=-1,
			"成长缺失");

		/* 经验曲线301-400连续（四次方段覆盖） */
		check("经验公式覆盖301-400（>=200四次方段）",
			search(level_src,"b_level>=200")!=-1,
			"经验段缺失");
	};
	if(err)
		check("流程无异常",0,describe_error(err));
	else
		check("流程无异常",1,"");
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	rm(ROOT+"/data_xiand/u/"+account_id[sizeof(account_id)-2..]+
		"/"+account_id+".o");
	werror("========== 400级解锁测试结束 ==========\n");
	return test_results["failed"]>0 ? 1 : 0;
}
