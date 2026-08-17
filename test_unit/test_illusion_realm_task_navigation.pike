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
	string daemon_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/seasonal_chard.pike") || "";
	string user_source = Stdio.read_file(ROOT+
		"/gamelib/clone/user.pike") || "";
	int travel_branch = search(source,
		"progress=SEASONALD->query_player_progress(me);\n"+
				"\t\t\t\twrite((string)travel[\"message\"]+\n"+
				"\t\t\t\t\tguided_follow_up(me,progress,1));")!=-1;
	int hunt_action = search(source,
		"[挂机至本章狩猎完成:illusion_realm hunt]")!=-1;
	int boss_action = search(source,
		"if(search(({\"boss\",\"story_boss\"}),kind)!=-1)")!=-1 &&
		search(source,"boss_challenge_link(chapter)")!=-1;
	int retry_action = search(source,
		"[重新查看本章:illusion_realm]|[返回游戏:look]")!=-1;
	int explore_arrival_action = search(source,
		"private string chapter_arrival_actions(mapping chapter)")!=-1 &&
		search(source,
			"[完成当前探索:illusion_realm next]")!=-1;
	int current_room_action =
		search(source,"chapter_target_in_current_room(me,chapter)")!=-1 &&
		search(source,
			"arrival_actions = chapter_arrival_actions(chapter)")!=-1 &&
		search(source,"query_chapter_task_view_for_test")!=-1;
	int quest_item_gate_action =
		search(source,"剧情道具：【")!=-1 &&
		search(source,"quest_item_drop_rate_text")!=-1 &&
		search(source,"quest_item_pity_kills")!=-1 &&
		search(source,"账号绑定且不可流转")!=-1 &&
		search(daemon_source,"drop_basis_points")!=-1 &&
		search(daemon_source,"random(10000)+1")!=-1;
	int chapter_hunt_return_action =
		search(daemon_source,"return_completed_chapter_task_view")!=-1 &&
		search(daemon_source,"player->command(\"illusion_realm\")")!=-1 &&
		search(daemon_source,
			"/tmp/illusion_chapter_return_pending")!=-1;
	int aligned_navigation =
		search(user_source,
			"[物品:inventory]|[地图:map_display]|[任务:mytasks]|[队伍:my_term]")!=-1 &&
		search(user_source,
			"[幻境任务:illusion_realm]|[挑战难度:personal_difficulty]|[限时玩法:timed_event]|[传送:userlist]")!=-1 &&
		search(user_source,
			"[共享宠物:pet]|[本命灵伴:spirit_companion]|[帮派:my_bang]|[江湖:my_games]")!=-1 &&
		search(user_source,
			"[玉石:yushi_change]|[仙玉:yushi_myzone]|[会员:vip_service_list]|[设置:game_detail]")!=-1 &&
		search(user_source,"【冒险】[物品:inventory]")==-1 &&
		search(user_source,"【修行】[幻境任务:illusion_realm]")==-1 &&
		search(user_source,"【伙伴】[共享宠物:pet]")==-1 &&
		search(user_source,"【资产】[玉石:yushi_change]")==-1;

	werror("\n========== 幻境任务传送入口回归测试 ==========\n");
	check("传送成功后重新读取进度并按任务类型渲染下一步",
		travel_branch,
		"story travel成功分支没有调用guided_follow_up(me,progress,1)");
	check("小怪章节传送后保留挂机到本章完成入口",
		hunt_action,
		"缺少illusion_realm hunt操作链接");
	check("首领章节传送后保留直接挑战入口",
		boss_action,
		"boss/story_boss没有进入boss_challenge_link");
	check("传送失败时保留重试和返回游戏入口",
		retry_action,
		"失败页面缺少重新查看本章或返回游戏入口");
	check("探索章节到达后提供明确的完成探索入口",
		explore_arrival_action,
		"探索到达页仍只会重复传送，无法确认本次到访");
	check("已在章节目标房时直接显示操作而不要求重复点击下一步",
		current_room_action,
		"当前历程没有复用目标房间的狩猎、首领或探索操作入口");
	check("概率剧情道具显示来源、掉率、保底与账号绑定规则",
		quest_item_gate_action,
		"剧情道具卡点没有向玩家解释掉落与保底进度");
	check("任务挂机达标脱战后自动回到幻境任务界面",
		chapter_hunt_return_action,
		"限章挂机只停止但没有安排脱战后的任务页回跳");
	check("游戏尾部快捷入口保持每行四项且左侧无分组前缀",
		aligned_navigation,
		"快捷入口未对齐、顺序变化或重新出现分组前缀");
	werror("结果: %d/%d 通过\n",results["passed"],results["total"]);
	return results["failed"] ? 1 : 0;
}
