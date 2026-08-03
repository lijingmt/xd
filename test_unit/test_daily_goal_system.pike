#!/usr/bin/env pike
/** 每日签到、真实行为目标、活跃宝箱与跨日边界回归。 */

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

string player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

void cleanup_player_file(string userid)
{
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_test_player(string userid)
{
	object player;
	cleanup_player_file(userid);
	player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(userid);
	player->name_cn = "每日修行测试";
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->level = 20;
	player->set_att_by_level();
	player->set_term("noterm");
	return player;
}

void destroy_test_player(object|zero player)
{
	string userid = "";
	if(!player)
		return;
	userid = player->query_name();
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
	cleanup_player_file(userid);
}

void test_compile_and_contracts()
{
	array(string) paths = ({
		"/gamelib/single/daemons/daily_goald.pike",
		"/gamelib/cmds/daily.pike",
		"/gamelib/cmds/mytasks.pike",
		"/gamelib/cmds/daily_cultivation.pike",
		"/gamelib/cmds/viceskill_dig.pike",
		"/gamelib/cmds/viceskill_gather.pike",
		"/gamelib/single/daemons/taskd.pike",
		"/gamelib/single/daemons/http_api_daemon.pike",
	});
	array(string) failures = ({});
	for(int i=0;i<sizeof(paths);i++){
		mixed err = catch { compile_file(ROOT+paths[i]); };
		if(err)
			failures += ({paths[i]+": "+describe_error(err)});
	}
	check("每日系统相关文件可由真实Pike运行时编译",
		!sizeof(failures),failures*" | ");
	object httpd = (object)(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string vue_source = Stdio.read_file(ROOT+"/vue_source/index.html");
	string app_source = Stdio.read_file(ROOT+"/vue_source/js/app.js");
	string task_source = Stdio.read_file(ROOT+"/gamelib/cmds/mytasks.pike");
	check("每日领取走HTTP核心锁且新旧界面都有入口",
		httpd && httpd->is_core_command("daily sign")==1 &&
		httpd->is_core_command("daily claim 100")==1 &&
		vue_source && search(vue_source,"sendQuickCommand('daily')")!=-1 &&
		app_source && search(app_source,"|daily|daily_cultivation")!=-1 &&
		task_source && search(task_source,"签到、目标与活跃宝箱")!=-1,
		"核心串行、Vue快捷入口、动画或旧任务页入口缺失");
}

void test_signin_and_activity_workflow()
{
	object player = create_test_player("xd99dailygoal01");
	int account_before = player ? player->query_account() : 0;
	int exp_before = player ? (int)player["current_exp"] : 0;
	mapping before = player ? DAILYGOALD->query_summary(player) : ([]);
	mapping sign = player ? DAILYGOALD->claim_signin(player) : ([]);
	mapping duplicate_sign = player ? DAILYGOALD->claim_signin(player) : ([]);
	mapping state = player ? DAILYGOALD->query_daily_state(player) : ([]);
	check("签到按自然日幂等并发放等级缩放经验金币",
		player && before["claimable"]==1 && sign["ok"] &&
		!duplicate_sign["ok"] && state["activity"]==10 &&
		state["sign_total"]==1 && player->query_account()>account_before &&
		(int)player["current_exp"]>=exp_before,
		"首签、重复拦截、活跃度或奖励错误");

	int invalid_kill = DAILYGOALD->record_kill(player,1);
	for(int i=0;i<5;i++)
		DAILYGOALD->record_kill(player,player->query_level());
	for(int i=0;i<5;i++)
		DAILYGOALD->record_skill(player);
	DAILYGOALD->record_task_completion(player);
	state = DAILYGOALD->query_daily_state(player);
	check("低级怪不计数且战斗、施法、任务形成80点基础闭环",
		!invalid_kill && state["progress"]["kill"]==5 &&
		state["progress"]["skill"]==5 &&
		state["progress"]["task"]==1 && state["activity"]==80,
		"等级防刷、进度封顶或基础活跃度错误");

	mapping chest20 = DAILYGOALD->claim_activity_reward(player,20);
	mapping chest50 = DAILYGOALD->claim_activity_reward(player,50);
	mapping chest80 = DAILYGOALD->claim_activity_reward(player,80);
	mapping duplicate50 = DAILYGOALD->claim_activity_reward(player,50);
	mapping early100 = DAILYGOALD->claim_activity_reward(player,100);
	check("20/50/80宝箱可领且重复领取与未达100点被拒绝",
		chest20["ok"] && chest50["ok"] && chest80["ok"] &&
		!duplicate50["ok"] && !early100["ok"],
		"活跃阈值或幂等领取凭据失效");

	for(int i=0;i<3;i++)
		DAILYGOALD->record_gather(player);
	state = DAILYGOALD->query_daily_state(player);
	mapping chest100 = DAILYGOALD->claim_activity_reward(player,100);
	for(int i=0;i<3;i++)
		DAILYGOALD->record_pet_assist(player);
	mapping summary = DAILYGOALD->query_summary(player);
	state = DAILYGOALD->query_daily_state(player);
	mapping task_activity = ([]);
	foreach(DAILYGOALD->query_daily_tasks(),mapping task)
		task_activity[(string)task["id"]] = (int)task["activity"];
	check("宠物或采集可独立补足20点且总活跃封顶100",
		state["activity"]==100 && state["progress"]["gather"]==3 &&
		state["progress"]["pet_assist"]==3 && chest100["ok"] &&
		task_activity["gather"]==20 && task_activity["pet_assist"]==20 &&
		summary["claimable_rewards"]==0 && summary["claimable"]==0,
		"可选目标、活跃上限、最终阈值或可领取提示错误");
	destroy_test_player(player);
}

void test_rollover_readonly_and_character_isolation()
{
	object first = create_test_player("xd99dailygoal02");
	object second = create_test_player("xd99dailygoal03");
	DAILYGOALD->claim_signin(first);
	first["/plus/daily_goal"] = ([
		"version":1,
		"date":DAILYGOALD->query_day_key()-1,
		"sign_total":7,
		"last_sign_date":DAILYGOALD->query_day_key()-1,
		"progress":(["kill":99]),
		"activity_claimed":(["20":1,"50":1]),
	]);
	mapping summary = DAILYGOALD->query_summary(first);
	int physical_date = (int)first["/plus/daily_goal"]["date"];
	int physical_kills = (int)first["/plus/daily_goal"]["progress"]["kill"];
	DAILYGOALD->record_skill(first);
	mapping rolled = DAILYGOALD->query_daily_state(first);
	mapping second_summary = DAILYGOALD->query_summary(second);
	check("状态轮询跨日只读，首次真实行为才清空昨日进度",
		summary["activity"]==0 && summary["claimable"]==1 &&
		physical_date==DAILYGOALD->query_day_key()-1 && physical_kills==99 &&
		rolled["date"]==DAILYGOALD->query_day_key() &&
		rolled["sign_total"]==7 && rolled["progress"]["kill"]==0 &&
		rolled["progress"]["skill"]==1 &&
		!sizeof((mapping)rolled["activity_claimed"]),
		"只读轮询写档、累计签到丢失或昨日状态残留");
	check("同账号体系下不同人物的每日进度彼此独立",
		second_summary["activity"]==0 && second_summary["claimable"]==1 &&
		!mappingp(second["/plus/daily_goal"]),
		"查询或第一人物操作污染第二人物档案");
	destroy_test_player(first);
	destroy_test_player(second);
}

int main()
{
	werror("\n========== 每日签到与目标系统测试 ==========\n");
	test_compile_and_contracts();
	test_signin_and_activity_workflow();
	test_rollover_readonly_and_character_isolation();
	werror("每日目标：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
