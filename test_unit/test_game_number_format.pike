#!/usr/bin/env pike
/** 服务端中文大数展示统一格式测试。 */

#include <globals.h>

int failures=0;

void check(string name,int valid,string detail)
{
	if(valid)
		werror("[数字缩写] ✓ %s\n",name);
	else{
		failures++;
		werror("[数字缩写] ✗ %s: %s\n",name,detail);
	}
}

void test_boundaries()
{
	mapping(int:string) expected = ([
		-2100000000:"-21亿",
		0:"0",
		9999:"9999",
		10000:"1万",
		12345:"1.23万",
		124000:"12.4万",
		1000000:"100万",
		3898800:"390万",
		99999999:"1亿",
		2100000000:"21亿",
		5858319000000:"5.86万亿",
	]);
	array(string) invalid=({});
	foreach(indices(expected),int value){
		string actual=format_game_number(value);
		if(actual!=expected[value])
			invalid+=({sprintf("%d=%s(expected %s)",value,actual,
				expected[value])});
	}
	check("万、亿、万亿、负数和进位边界统一为三位有效数字",
		!sizeof(invalid),invalid*", ");
}

void test_primary_server_ui_coverage()
{
	array(string) files=({
		"/gamelib/cmds/myhp.pike",
		"/gamelib/cmds/myinfo.pike",
		"/gamelib/cmds/look_top.pike",
		"/gamelib/inherit/npc.pike",
		"/lowlib/wapmud2/cmds/kill_quick.pike",
		"/lowlib/wapmud2/inherit/feature/fight.pike",
		"/lowlib/wapmud2/inherit/npc.pike",
	});
	array(string) missing=({});
	foreach(files,string file){
		string source=Stdio.read_file(ROOT+file);
		if(!source || search(source,"format_game_number(")==-1)
			missing+=({file});
	}
	check("人物状态、属性、战斗、怪物、快速战斗和排行榜共用服务端格式器",
		!sizeof(missing),"missing="+missing*", ");
}

void test_wealth_ranking_uses_gold_unit()
{
	object moneyd=(object)(ROOT+"/lowlib/mudlib/single/moneyd.pike");
	string source=Stdio.read_file(ROOT+"/gamelib/cmds/look_top.pike");
	check("富翁榜从内部银单位换算为金币单位",
		moneyd && moneyd->query_money_for_paihang(1234567)=="12345金",
		moneyd ? moneyd->query_money_for_paihang(1234567) : "moneyd missing");
	check("富翁榜使用货币格式器而非普通万亿缩写",
		source && search(source,"type==\"富翁\"")!=-1 &&
		search(source,"query_money_for_paihang(")!=-1,
		"富翁榜专用货币格式分支缺失");
}

int main()
{
	werror("\n========== 服务端中文数字缩写测试 ==========\n");
	test_boundaries();
	test_primary_server_ui_coverage();
	test_wealth_ranking_uses_gold_unit();
	werror("数字缩写测试：失败 %d\n",failures);
	return failures ? 1 : 0;
}
