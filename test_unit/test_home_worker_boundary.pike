#!/usr/bin/env pike
/** 家园跨Worker边界回归：非归属节点不得物化家园房间；
 跨节点访问必须带门牌号走标准移动重定向并在到达侧改道真实家园。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[家园Worker边界] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[家园Worker边界] ✗ %s: %s\n",name,detail);
	}
}

int source_has(string path,string needle)
{
	string source=Stdio.read_file(ROOT+path);
	return source && search(source,needle)!=-1;
}

int main()
{
	string homed_src=Stdio.read_file(ROOT+
		"/gamelib/single/daemons/homed.pike") || "";
	check("非归属Worker禁止物化家园房间（两个查询口都有归属门）",
		search(homed_src,
			"// 同 query_home_by_masterId：非归属Worker不得物化家园房间。")!=-1 &&
		search(homed_src,
			"// 家园房间只允许归属Worker物化：非归属节点克隆出的房间没有")!=-1,
		"物化门缺失，访客会在错误节点看到空假房");
	check("家园登记查询不物化房间",
		search(homed_src,"int query_home_registered(string masterId)")!=-1,
		"缺少只读登记查询");
	check("跨节点进园先写门牌号再走标准移动",
		source_has("/gamelib/cmds/home_visit.pike",
			"HOME_MAIN_TEMPLATE") &&
		source_has("/gamelib/cmds/home_return.pike",
			"HOME_MAIN_TEMPLATE"),
		"入口命令缺少门牌号重定向");
	string arrival_src=Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike") || "";
	check("到达侧按门牌号改道真实家园房间",
		search(arrival_src,"stage=home_room")!=-1 &&
		search(arrival_src,
			"affinity==(string)player->query_inhome_pos()")!=-1,
		"跨节点到达会落进空的静态模板房");
	werror("家园Worker边界：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
