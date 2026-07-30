#!/usr/bin/env pike
/**
 * 七职业每级历练真实测试：
 * - 七职业1-500级无断档
 * - 真实同阶击杀、越级边界、职业切换与重复领奖保护
 * - 任务列表、新手引导、HTTP核心命令与NPC死亡链完整接线
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total":0,
	"passed":0,
	"failed":0,
]);

void test_start(string name)
{
	test_results["total"]++;
	werror("\n[每级职业历练 %d] %s\n",test_results["total"],name);
}

void test_pass()
{
	test_results["passed"]++;
	werror("  ✓ 通过\n");
}

void test_fail(string reason)
{
	test_results["failed"]++;
	werror("  ✗ 失败: %s\n",reason);
}

object create_player(string name,string race_id,
	string profession_id,int level)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = "每级历练测试人物";
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race_id);
	player->set_profeId(profession_id);
	player->setup_player(race_id,profession_id);
	player->level = level;
	player->set_att_by_level();
	return player;
}

void destroy_player(object|zero player)
{
	if(!player)
		return;
	SUMMOND->dismiss_all(player->query_name());
	foreach(all_inventory(player),object item)
		destruct(item);
	destruct(player);
}

void test_all_professions_all_levels()
{
	test_start("七职业1至500级动态任务无断档且文案独立");
	mapping(string:string) professions = ([
		"jianxian":"剑仙",
		"yushi":"羽士",
		"zhuxian":"诛仙",
		"kuangyao":"狂妖",
		"wuyao":"巫妖",
		"yinggui":"影鬼",
		"fangshi":"方士",
	]);
	mapping(string:int) titles = ([]);
	int checked = 0;
	int failed = 0;

	foreach(sort(indices(professions)),string profession_id){
		string base_name =
			TASKD->query_growth_task_base_name(profession_id);
		if(titles[base_name])
			failed++;
		titles[base_name] = 1;
		for(int level=1;level<=MAX_LEVEL;level++){
			string title =
				TASKD->query_growth_task_title(profession_id,level);
			int required = TASKD->query_growth_task_required(level);
			int exp = TASKD->query_growth_task_exp(level);
			int money = TASKD->query_growth_task_money(level);
			checked++;
			if(!TASKD->is_growth_task_profession(profession_id) ||
			   search(title,professions[profession_id])==-1 ||
			   search(title,(string)level+"级")==-1 ||
			   required<3 || required>12 ||
			   exp<=0 || money<=0)
				failed++;
		}
	}

	if(checked==7*MAX_LEVEL && failed==0 && sizeof(titles)==7)
		test_pass();
	else
		test_fail(sprintf(
			"覆盖=%d/%d，失败=%d，独立标题=%d",
			checked,7*MAX_LEVEL,failed,sizeof(titles)));
}

void test_real_kill_and_reward_workflow()
{
	test_start("真实击杀推进、完成、领奖和同级防重复");
	object player =
		create_player("__testunit_growth_workflow__",
			"human","jianxian",42);
	int accept_result = 0;
	int too_low = -1;
	int last_kill = 0;
	int extra_kill = -1;
	int required = 0;
	int exp_before = 0;
	int money_before = 0;
	mapping state = ([]);
	mapping award = ([]);
	int repeat_accept = 0;
	string history = "";
	string error_desc = "";

	mixed err = catch {
		exp_before = player->query_exp();
		money_before = player->query_account();
		accept_result = TASKD->accept_growth_task(player);
		state = TASKD->query_growth_task_state(player);
		required = state["required"];
		too_low = TASKD->if_in_killTask(player,"测试低级怪",36);
		// 模拟旧存档或异常值；服务端必须按等级恢复真实要求。
		player["/taskd/growth_active"]["required"] = 1;
		for(int i=0;i<required;i++)
			last_kill = TASKD->if_in_killTask(
				player,"测试同阶怪",42);
		extra_kill = TASKD->if_in_killTask(
			player,"测试同阶怪",42);
		state = TASKD->query_growth_task_state(player);
		award = TASKD->claim_growth_task(player);
		repeat_accept = TASKD->accept_growth_task(player);
		history = TASKD->queryTaskHistory(player);
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && accept_result==1 &&
	   too_low==0 && last_kill==1 && extra_kill==0 &&
	   state["progress"]==required &&
	   award["code"]==6 && award["level"]==42 &&
	   player->query_exp()-exp_before==
		TASKD->query_growth_task_exp(42) &&
	   player->query_account()-money_before==
		TASKD->query_growth_task_money(42) &&
		TASKD->query_growth_task_done(player,42) &&
	   sizeof(TASKD->query_growth_task_state(player))==0 &&
	   repeat_accept==5 &&
	   search(history,"每级职业历练：已完成1个等级")!=-1)
		test_pass();
	else
		test_fail(sprintf(
			"accept=%d low=%d last=%d extra=%d award=%O repeat=%d: %s",
			accept_result,too_low,last_kill,extra_kill,
			award,repeat_accept,error_desc));
	destroy_player(player);
}

void test_boundaries_and_profession_lock()
{
	test_start("等级±5边界、满级奖励与职业切换保护");
	object level_one =
		create_player("__testunit_growth_level_one__",
			"monst","wuyao",1);
	object max_level =
		create_player("__testunit_growth_max_level__",
			"third","fangshi",MAX_LEVEL);
	object changed =
		create_player("__testunit_growth_changed__",
			"human","yushi",70);
	int level_one_ok = 0;
	int max_ok = 0;
	int changed_ok = 0;
	string error_desc = "";

	mixed err = catch {
		TASKD->accept_growth_task(level_one);
		int reject_seven =
			TASKD->if_in_killTask(level_one,"七级怪",7);
		int accept_six =
			TASKD->if_in_killTask(level_one,"六级怪",6);
		level_one_ok = reject_seven==0 && accept_six==1;

		TASKD->accept_growth_task(max_level);
		mapping max_state =
			TASKD->query_growth_task_state(max_level);
		int max_exp_before = max_level->query_exp();
		int max_money_before = max_level->query_account();
		int reject_494 =
			TASKD->if_in_killTask(max_level,"四九四级怪",494);
		for(int i=0;i<max_state["required"];i++)
			TASKD->if_in_killTask(
				max_level,"四九五级怪",MAX_LEVEL-5);
		mapping max_award = TASKD->claim_growth_task(max_level);
		max_ok = reject_494==0 &&
			max_award["code"]==6 &&
			max_award["exp"]==0 &&
			max_level->query_exp()==max_exp_before &&
			max_level->query_account()-max_money_before==
				TASKD->query_growth_task_money(MAX_LEVEL);

		TASKD->accept_growth_task(changed);
		changed->set_profeId("jianxian");
		int changed_kill =
			TASKD->if_in_killTask(changed,"同阶怪",70);
		mapping changed_award =
			TASKD->claim_growth_task(changed);
		changed->set_profeId("yushi");
		int restored_kill =
			TASKD->if_in_killTask(changed,"同阶怪",70);
		changed_ok = changed_kill==0 &&
			changed_award["code"]==2 &&
			restored_kill==1;
	};
	if(err)
		error_desc = describe_error(err);

	if(!err && level_one_ok && max_ok && changed_ok)
		test_pass();
	else
		test_fail(sprintf(
			"一级=%d 满级=%d 转职=%d: %s",
			level_one_ok,max_ok,changed_ok,error_desc));
	destroy_player(level_one);
	destroy_player(max_level);
	destroy_player(changed);
}

void test_seven_profession_runtime_acceptance()
{
	test_start("七职业真实人物均可领取且高等级老人物无需补做旧级");
	mapping(string:string) races = ([
		"jianxian":"human",
		"yushi":"human",
		"zhuxian":"human",
		"kuangyao":"monst",
		"wuyao":"monst",
		"yinggui":"monst",
		"fangshi":"third",
	]);
	int accepted = 0;
	int failed = 0;

	foreach(sort(indices(races)),string profession_id){
		object player = create_player(
			"__testunit_growth_"+profession_id+"__",
			races[profession_id],profession_id,73);
		if(!player || TASKD->accept_growth_task(player)!=1)
			failed++;
		else{
			mapping state = TASKD->query_growth_task_state(player);
			if(state["level"]==73 &&
			   state["profession"]==profession_id)
				accepted++;
			else
				failed++;
		}
		destroy_player(player);
	}

	if(accepted==7 && failed==0)
		test_pass();
	else
		test_fail(sprintf("领取=%d，失败=%d",accepted,failed));
}

void test_ui_and_event_wiring()
{
	test_start("任务入口、引导、HTTP锁和三条NPC死亡路径完整接线");
	object player =
		create_player("__testunit_growth_ui__",
			"third","fangshi",53);
	object command =
		(object)(ROOT+"/gamelib/cmds/growth_task.pike");
	string page = TASKD->queryGrowthTaskPage(player);
	string task_list = TASKD->queryMyTasks(player);
	string guide =
		Stdio.read_file(ROOT+"/gamelib/cmds/newbie_guide.pike");
	string npc =
		Stdio.read_file(ROOT+"/gamelib/inherit/npc.pike");
	string thread_manager = Stdio.read_file(
		ROOT+"/gamelib/single/daemons/_http_api_mod/thread_manager.pike");
	int npc_hooks = 0;
	int pos = 0;
	string needle = "this_object()->query_level());";

	while(npc && (pos=search(npc,needle,pos))!=-1){
		npc_hooks++;
		pos += sizeof(needle);
	}

	if(command &&
	   search(page,"【方士】灵契巡游")!=-1 &&
	   search(page,"growth_task accept")!=-1 &&
	   search(task_list,"【每级职业历练】")!=-1 &&
	   search(task_list,":growth_task]")!=-1 &&
	   guide && search(guide,
		"[每级职业历练:growth_task]")!=-1 &&
	   thread_manager && search(thread_manager,
		"\"growth_task\"")!=-1 &&
	   npc_hooks>=3)
		test_pass();
	else
		test_fail(sprintf(
			"command=%O npc_hooks=%d page=%d list=%d guide=%d lock=%d",
			command,npc_hooks,
			search(page,"growth_task accept"),
			search(task_list,":growth_task]"),
			guide ? search(guide,"[每级职业历练:growth_task]") : -1,
			thread_manager ? search(thread_manager,
				"\"growth_task\"") : -1));
	destroy_player(player);
}

int main(int argc,array(string) argv)
{
	werror("\n╔════════════════════════════════════════════════╗\n");
	werror("║          七职业每级历练完整测试              ║\n");
	werror("╚════════════════════════════════════════════════╝\n");

	test_all_professions_all_levels();
	test_real_kill_and_reward_workflow();
	test_boundaries_and_profession_lock();
	test_seven_profession_runtime_acceptance();
	test_ui_and_event_wiring();

	werror("\n每级职业历练测试：%d通过，%d失败\n",
		test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
