#!/usr/bin/env pike
/** 815703501 真实生产档案本地还原验证（任务#27）：
 * 1) 主号与S1角色档案在当前代码下完整还原（无字段崩溃）；
 * 2) 本地测试口令重置（仅本地副本，供API登录验证用）。 */

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

void sanitize_save(string userid)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->restore();
	check(userid+" 生产档案完整还原",
		objectp(player) && (string)player->query_name()==userid &&
		(int)player->query_level()>0,
		sprintf("level=%d",player?(int)player->query_level():-1));
	player->set_password("testunit88");
	check(userid+" 本地测试口令写入",
		player->save_with_result(),"save_with_result failed");
	destruct(player);
}

int main()
{
	werror("\n========== 815703501 档案还原验证 ==========\n");
	mixed err = catch{
		sanitize_save("xd01815703501");
		sanitize_save("xd01815703501c1455d3607b");
	};
	if(err)
		check("生产档案还原无异常",0,describe_error(err));
	else
		check("生产档案还原无异常",1,"");
	werror("========== 还原验证结束 ==========\n");
	return test_results["failed"]>0 ? 1 : 0;
}
