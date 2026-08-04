#!/usr/bin/env pike
/** 神秘商店货币和无等级装备停产回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	test_results["total"]++;
	if(valid){
		test_results["passed"]++;
		werror("[稀有经济] ✓ %s\n",name);
	}
	else{
		test_results["failed"]++;
		werror("[稀有经济] ✗ %s: %s\n",name,detail);
	}
}

int main()
{
	string shop = Stdio.read_file(ROOT+"/lowlib/wapmud2/cmds/list_spec.pike");
	string boss = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/bossdropd.pike");
	string items = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/itemsd.pike");
	mixed shop_compile = catch {
		compile_file(ROOT+"/lowlib/wapmud2/cmds/list_spec.pike");
	};
	mixed boss_compile = catch {
		compile_file(ROOT+"/gamelib/single/daemons/bossdropd.pike");
	};
	check("神秘技能货架仅接受服务端固定30碎玉",
		!shop_compile && shop && search(shop,"type==2 ? 30 : 10")!=-1 &&
		search(shop,"pay_yushi(me,need_amount)")!=-1 &&
		search(shop,"1000000000")==-1 && search(shop,"pay_money") == -1,
		"仍存在客户端金额、金币或编译错误");
	check("Boss新装备不再随机生成无等级需求",
		!boss_compile && boss && search(boss,"set_item_canLevel(-1)")==-1 &&
		search(boss,"set_item_canLevel(\"+boss_level+\");")!=-1,
		"Boss生成器仍可能写入-1或编译失败");
	check("普通掉落仅保留显式旧装备-1兼容入口",
		items && search(items,"if(flag_no_level == 1)")!=-1 &&
		search(items,"random(10000)<=1 || flag_no_level") == -1 &&
		search(items,"rtn_ob->query_item_canLevel()<0")!=-1 &&
		search(items,"rtn_ob->set_item_canLevel(target_item_level)")!=-1 &&
		search(items,"只兼容旧无等级装备明确传入-1后的炼化")!=-1,
		"随机无等级分支仍存在或旧数据兼容说明缺失");
	werror("稀有经济：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
