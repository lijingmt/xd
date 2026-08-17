#!/usr/bin/env pike
/** 新月幻境任务传送后操作入口回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

int main()
{
	string source = Stdio.read_file(ROOT+
		"/gamelib/cmds/illusion_realm.pike") || "";
	int travel_branch = search(source,
		"progress=SEASONALD->query_player_progress(me);\n"+
				"\t\t\t\twrite((string)travel[\"message\"]+\n"+
				"\t\t\t\t\tguided_follow_up(progress,1));")!=-1;
	int hunt_action = search(source,
		"[挂机至本章狩猎完成:illusion_realm hunt]")!=-1;
	int boss_action = search(source,
		"if(after_travel && search(({\"boss\",\"story_boss\"}),kind)!=-1)")!=-1 &&
		search(source,"boss_challenge_link(chapter)")!=-1;
	int retry_action = search(source,
		"[重新查看本章:illusion_realm]|[返回游戏:look]")!=-1;

	werror("\n========== 幻境任务传送入口回归测试 ==========\n");
	check("传送成功后重新读取进度并按任务类型渲染下一步",
		travel_branch,
		"story travel成功分支没有调用guided_follow_up(progress,1)");
	check("小怪章节传送后保留挂机到本章完成入口",
		hunt_action,
		"缺少illusion_realm hunt操作链接");
	check("首领章节传送后保留直接挑战入口",
		boss_action,
		"boss/story_boss没有进入boss_challenge_link");
	check("传送失败时保留重试和返回游戏入口",
		retry_action,
		"失败页面缺少重新查看本章或返回游戏入口");
	werror("结果: %d/%d 通过\n",results["passed"],results["total"]);
	return results["failed"] ? 1 : 0;
}
