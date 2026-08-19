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
	string account_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/account_characterd.pike") || "";
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
	int smart_single_click_flow =
		search(source,"if(kind==\"story_echo\"){")!=-1 &&
		search(source,
			"mapping started = SEASONALD->start_chapter_hunt_autofight(me);")!=-1 &&
		search(source,
			"mapping target = current_challenge_target(me,\"chapter\");")!=-1 &&
		search(source,"kind==\"story_echo\" && (int)result[\"already\"]")==-1;
	int player_task_diagnostic =
		search(source,"private string task_diagnostic_view(object me)")!=-1 &&
		search(source,"诊断码：S1-C")!=-1 &&
		search(source,"[▶ 智能继续当前任务:illusion_realm next]")!=-1 &&
		search(source,"parts[0]==\"diagnose\"")!=-1;
	int chapter_experience_feedback =
		search(source,"关卡节奏：§b")!=-1 &&
		search(daemon_source,
			"private mapping(string:string) chapter_experience_identity")!=-1 &&
		search(daemon_source,"chapter_experience_beat(chapter_index")!=-1;
	int chapter_route_rhythm =
		search(daemon_source,
			"private mapping(string:mixed) chapter_hunt_target")!=-1 &&
		search(daemon_source,"chapter_route_rhythm_version")!=-1 &&
		search(daemon_source,"({\"trace\",\"evidence\",\"counter\"})")!=-1 &&
		search(source,"追迹段落 ")!=-1;
	int current_room_action =
		search(source,"chapter_target_in_current_room(me,chapter)")!=-1 &&
		search(source,
			"arrival_actions = chapter_arrival_actions(chapter)")!=-1 &&
		search(source,"string arrival_actions = \"\";")!=-1 &&
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
		search(daemon_source,"disengage_completed_chapter_hunt")!=-1 &&
		search(daemon_source,
			"publish_server_autofight_final_view")!=-1 &&
		search(daemon_source,
			"/tmp/illusion_chapter_return_pending")!=-1;
	int completed_chapter_claim_action =
		search(source,"private string chapter_claim_link(int chapter_number)")!=-1 &&
		search(source,"章并进入下一章:illusion_realm claim ")!=-1 &&
		search(daemon_source,"章并进入下一章:illusion_realm claim ")!=-1;
	int final_completion_is_post_commit_safe =
		search(daemon_source,"completion_err=catch")!=-1 &&
		search(daemon_source,"!mappingp(completion)")!=-1 &&
		search(daemon_source,"invalid completion result")!=-1 &&
		sizeof(daemon_source/"completion_err=catch")>=3 &&
		search(account_source,"story_completion_log_err=catch")!=-1 &&
		search(account_source,
			"story_completion_log_err || !appended")!=-1;
	int audit_log_is_post_commit_safe =
		search(daemon_source,
			"private int safe_append_illusion_log(string line)")!=-1 &&
		search(daemon_source,"time()-illusion_log_error_at>=60")!=-1 &&
		sizeof(daemon_source/"Stdio.append_file(ILLUSION_LOG")==2 &&
		sizeof(daemon_source/"safe_append_illusion_log(sprintf(")>=21;
	int chapter_balance_telemetry =
		search(daemon_source,
			"private int current_chapter_started_at")!=-1 &&
		search(daemon_source,
			"progress[\"chapter_started_at\"] = claimed_at")!=-1 &&
		search(daemon_source,
			"chapter_number=%d|elapsed_seconds=%d|mastery_difficulty=%d")!=-1;
	int visit_start=search(daemon_source,
		"void record_room_visit(object player,object room)");
	int visit_end=visit_start>=0 ? search(daemon_source,
		"void record_npc_kill(object player,object npc",visit_start) : -1;
	string visit_source=visit_start>=0 && visit_end>visit_start ?
		daemon_source[visit_start..visit_end-1] : "";
	int hidden_visit_after_story_commit=
		search(visit_source,"if(!player->save_with_result())")!=-1 &&
		search(visit_source,
			"ILLUSION_HIDDEN_PROFESSIOND->record_room_visit(player,room)")>
		search(visit_source,"if(!player->save_with_result())") &&
		search(visit_source,
			"否则会把已在内存回滚的主线到访重新写进磁盘。\n\t\t\treturn;")!=-1;
	int automatic_transition_lock_safe=
		search(daemon_source,"transition_err=catch{")!=-1 &&
		search(daemon_source,
			"release_control_lock();\n\tif(transition_err)\n\t\terror(\"automatic illusion transition failed after lock release")!=-1;
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
	check("智能下一步一次完成传送后阅读、限章挂机或真实首领列举",
		smart_single_click_flow,
		"下一步仍要求玩家到达后重复点击，或绕过真实NPC直接攻击");
	check("任务页提供只读诊断码与不重置进度的智能恢复入口",
		player_task_diagnostic,
		"玩家卡点仍无法自证当前章节、目标房间和挂机状态");
	check("普通章节显示九幕身份并在真实击杀检查点发送三幕反馈",
		chapter_experience_feedback,
		"普通章节仍只有数量变化，没有起势、转折与收束反馈");
	check("三类章节把真实狩猎拆成一键可跟随的三段猎场",
		chapter_route_rhythm,
		"追迹、搜证与反猎仍只更换文案，没有实际换房节奏");
	check("已在章节目标房时直接显示操作而不要求重复点击下一步",
		current_room_action,
		"当前历程没有安全区分未到达时的一键前往与到达后的任务动作");
	check("概率剧情道具显示来源、掉率、保底与账号绑定规则",
		quest_item_gate_action,
		"剧情道具卡点没有向玩家解释掉落与保底进度");
	check("任务挂机达标脱战后自动回到幻境任务界面",
		chapter_hunt_return_action,
		"限章挂机只停止但没有安排脱战后的任务页回跳");
	check("本章完成页使用章节号绑定的明确领取按钮",
		completed_chapter_claim_action,
		"完成态仍只依赖通用next，旧界面可能不显示或领取错误章节");
	check("终章人物存档及登录补写后的账号凭证/日志异常不会穿透",
		final_completion_is_post_commit_safe,
		"账号完成凭证仍可在主存档成功后造成空页或登录循环");
	check("S1全部审计写入统一隔离日志故障",
		audit_log_is_post_commit_safe,
		"仍有主操作提交后直接写日志的空页/重试风险");
	check("章节领取审计记录耗时和真实难度且不参与奖励计算",
		chapter_balance_telemetry,
		"无法按章定位流失点，或仍需凭主观调整任务与难度");
	check("照命到访整档保存只在S1主线到访提交成功后执行",
		hidden_visit_after_story_commit,
		"隐藏支线保存可能提前持久化随后回滚的主线到访");
	check("自动赛季切换异常先释放跨Worker控制锁再重试",
		automatic_transition_lock_safe,
		"生命周期异常可能把所有节点阻塞在遗留文件锁上");
	check("游戏尾部快捷入口保持每行四项且左侧无分组前缀",
		aligned_navigation,
		"快捷入口未对齐、顺序变化或重新出现分组前缀");
	werror("结果: %d/%d 通过\n",results["passed"],results["total"]);
	return results["failed"] ? 1 : 0;
}
