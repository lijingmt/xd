#!/usr/bin/env pike
/**
 * 玩家档案安全测试：原子替换、上一版备份、损坏档恢复。
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
	werror("\n[玩家存档安全 %d] %s\n",test_results["total"],name);
}

void test_result(int passed,string reason)
{
	if(passed){
		test_results["passed"]++;
		werror("  ✓ 通过\n");
	}
	else{
		test_results["failed"]++;
		werror("  ✗ 失败: %s\n",reason);
	}
}

void cleanup_files(string filepath)
{
	rm(filepath);
	rm(filepath+".tmp");
	rm(filepath+".bak");
	rm(filepath+".bak.tmp");
}

void test_atomic_save_and_restore()
{
	string player_name = "__testunit_atomic_save_99";
	string filepath = DATA_ROOT+"u/99/"+player_name+".o";
	object|zero player = 0;
	object|zero restored = 0;
	string first_save = "";
	string second_save = "";
	string backup_save = "";
	string error_desc = "";
	int restore_ok = 0;
	int valid = 0;
	test_start("两次存档保留当前档和上一版备份，空档可从备份恢复");
	cleanup_files(filepath);
	mixed err = catch{
		player = clone(GAMELIB_USER);
		player->set_name(player_name);
		player->name_cn = "原子存档测试";
		player->set_project("gamelib");
		player->setup("testunit-only");
		player->level = 14;
		player->set_att_by_level();
		player->set_links("不应持久化的界面链接");
		player->set_inventory_links("不应持久化的物品链接");
		player->save();
		first_save = Stdio.read_file(filepath);
		if(!first_save)
			first_save = "";
		player->level = 22;
		player->set_att_by_level();
		player->save();
		second_save = Stdio.read_file(filepath);
		if(!second_save)
			second_save = "";
		backup_save = Stdio.read_file(filepath+".bak");
		if(!backup_save)
			backup_save = "";
		Stdio.write_file(filepath,"");
		restored = clone(GAMELIB_USER);
		restored->set_name(player_name);
		restored->set_project("gamelib");
		restore_ok = restored->restore();
		valid = search(first_save,"\nlevel 14\n")!=-1 &&
			search(second_save,"\nlevel 22\n")!=-1 &&
			search(first_save,"\nlinks ")==-1 &&
			search(first_save,"\ninventory_links ")==-1 &&
			backup_save==first_save && restore_ok==1 &&
			restored->query_level()==14 &&
			Stdio.file_size(filepath+".tmp")<0 &&
			Stdio.file_size(filepath+".bak.tmp")<0;
	};
	if(err)
		error_desc = describe_error(err);
	test_result(!err && valid,"原子存档或备份恢复失败: "+error_desc);
	if(player)
		destruct(player);
	if(restored)
		destruct(restored);
	cleanup_files(filepath);
}

void test_autosave_schedule_contract()
{
	string source = "";
	int first_schedule = -1;
	int repeat_schedule = -1;
	test_start("30秒定时存档使用唯一自续链，不因暂无地图中断");
	source = Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	if(source){
		first_schedule = search(source,
			"call_out(save,SAVE_TIME,1);");
		if(first_schedule!=-1)
			repeat_schedule = search(source,
				"call_out(save,SAVE_TIME,1);",
				first_schedule+1);
	}
	test_result(source &&
		search(source,"#define SAVE_TIME 30")!=-1 &&
		first_schedule!=-1 && repeat_schedule!=-1 &&
		search(source,"if(autosave)\n\t\tcall_out(save,SAVE_TIME,1);")!=-1 &&
		search(source,"this_object()->links = 0;")!=-1 &&
		search(source,"this_object()->inventory_links = 0;")!=-1 &&
		search(source,
			"if(!environment(this_object())){\n\t\t//destruct(this_object());\n\t\treturn;") == -1,
		"自动存档调度仍可能停止或被手动存档重复创建");
}

void test_persistent_activity_timer_rebuild()
{
	string player_name = "__testunit_activity_timer_97";
	string filepath = DATA_ROOT+"u/97/"+player_name+".o";
	object|zero player = 0;
	object|zero restored = 0;
	string saved = "";
	string error_desc = "";
	int valid = 0;
	test_start("睡眠闭关截止时间可跨对象重建且过期状态自动释放");
	cleanup_files(filepath);
	mixed err = catch {
		player = clone(GAMELIB_USER);
		player->set_name(player_name);
		player->set_password("testunit-only");
		player->set_project("gamelib");
		player->sleep_for_learn(2);
		int original_remaining = player->query_doing_status_remaining();
		player->save();
		saved = Stdio.read_file(filepath) || "";
		destruct(player);
		player = 0;
		restored = clone(GAMELIB_USER);
		restored->set_name(player_name);
		restored->set_project("gamelib");
		int restored_ok = restored->restore();
		int timer_ok = restored->restore_persistent_activity_state();
		int restored_remaining = restored->query_doing_status_remaining();
		int persisted = search(saved,"\ndoing_status_until ")!=-1 &&
			search(saved,"\ndoing_status ")!=-1 &&
			search(saved,"\nunconscious_msg ")!=-1 &&
			search(saved,"\nwake_up_msg ")!=-1;
		restored->set_doing_status_until(time()-1);
		int expired_rejected = !restored->restore_persistent_activity_state();
		valid = original_remaining>0 && original_remaining<=120 &&
			restored_ok==1 && timer_ok==1 && restored_remaining>0 &&
			restored_remaining<=original_remaining && persisted &&
			expired_rejected && !restored->query_doing_status() &&
			restored->query_doing_status_remaining()==0;
	};
	if(err)
		error_desc = describe_error(err)+" "+describe_backtrace(err);
	test_result(!err && valid,
		"活动截止时间未持久化、重建时被延长或过期后仍禁用命令: "+
		error_desc);
	if(player)
		destruct(player);
	if(restored)
		destruct(restored);
	cleanup_files(filepath);
}

void test_paid_training_worker_and_restart_recovery()
{
	string player_name = "__testunit_paid_training_96";
	string filepath = DATA_ROOT+"u/96/"+player_name+".o";
	object|zero player = 0;
	object|zero restored = 0;
	string saved = "";
	string error_desc = "";
	int valid = 0;
	test_start("付费打坐进度进入唯一人物档案并可在新Worker恢复");
	cleanup_files(filepath);
	mixed err = catch {
		player=clone(GAMELIB_USER);
		player->set_name(player_name);
		player->set_password("testunit-only");
		player->set_project("gamelib");
		player->level=10;
		AUTO_LEARND->add_new_player("dazuo",player,12);
		player->sleep_for_learn(12);
		AUTO_LEARND->prepare_worker_handoff(player);
		int before=player->query_doing_status_remaining();
		int save_ok=player->save_with_result();
		saved=Stdio.read_file(filepath) || "";
		AUTO_LEARND->detach_worker_handoff(player);
		destruct(player);
		player=0;
		restored=clone(GAMELIB_USER);
		restored->set_name(player_name);
		restored->set_project("gamelib");
		int restore_ok=restored->restore();
		mapping forged_runtime=restored->query_auto_learn_runtime();
		forged_runtime["speed"]=999999999;
		restored->set_auto_learn_runtime(forged_runtime);
		int resumed=AUTO_LEARND->resume_player(restored);
		mapping runtime=restored->query_auto_learn_runtime();
		mapping daemon_runtime=AUTO_LEARND->query_player_info(player_name);
		int after=restored->query_doing_status_remaining();
		restored->wakeup_from_auto_learn();
		string cleared=AUTO_LEARND->clear_user(restored);
		valid=save_ok==1 && restore_ok==1 && resumed==1 && before>0 &&
			after>0 && after<=before && (string)runtime["type"]=="dazuo" &&
			(int)runtime["time_max"]==12 &&
			(int)daemon_runtime["speed"]==
				AUTO_LEARND->work_out_speed(10,"dazuo") &&
			(int)runtime["remaining_seconds"]>0 &&
			search(saved,"\nauto_learn_runtime ")!=-1 &&
			search(cleared,"还剩余12分钟")!=-1 &&
			!sizeof(restored->query_auto_learn_runtime()) &&
			!AUTO_LEARND->is_now_auto_learn(player_name);
	};
	if(err)
		error_desc=describe_error(err)+" "+describe_backtrace(err);
	test_result(!err && valid,
		"修炼会话未持久化、恢复时长被延长或源Worker仍有幽灵会话: "+
		error_desc);
	if(player)
		destruct(player);
	if(restored)
		destruct(restored);
	cleanup_files(filepath);
}

void test_ghost_worker_and_restart_recovery()
{
	string player_name="__testunit_ghost_recovery_95";
	string filepath=DATA_ROOT+"u/95/"+player_name+".o";
	object|zero player=0;
	object|zero restored=0;
	string saved="";
	string error_desc="";
	int valid=0;
	test_start("鬼魂标记与复原时间可跨Worker和重启恢复");
	cleanup_files(filepath);
	mixed err=catch {
		player=clone(GAMELIB_USER);
		player->set_name(player_name);
		player->name_cn="鬼魂恢复测试";
		player->set_password("testunit-only");
		player->set_project("gamelib");
		player->ghost();
		int before=player->query_ghost_until()-time();
		int save_ok=player->save_with_result();
		saved=Stdio.read_file(filepath) || "";
		destruct(player);
		player=0;
		restored=clone(GAMELIB_USER);
		restored->set_name(player_name);
		restored->set_project("gamelib");
		int restore_ok=restored->restore();
		int timer_ok=restored->restore_persistent_ghost_state();
		int after=restored->query_ghost_until()-time();
		int restored_ghost=restored->is_ghost();
		restored->set_ghost_until(time()-1);
		int expired_rejected=!restored->restore_persistent_ghost_state();
		valid=save_ok==1 && restore_ok==1 && before>0 && before<=120 &&
			timer_ok==1 && restored_ghost==1 && after>0 && after<=before &&
			expired_rejected && !restored->fake_name_cn &&
			search(saved,"\n_ghost 1\n")!=-1 &&
			search(saved,"\nghost_until ")!=-1;
	};
	if(err)
		error_desc=describe_error(err)+" "+describe_backtrace(err);
	test_result(!err && valid,
		"鬼魂状态未持久化、时长被延长或过期后仍未清理: "+
		error_desc);
	if(player)
		destruct(player);
	if(restored)
		destruct(restored);
	cleanup_files(filepath);
}

void test_shutdown_save_contract()
{
	string source = Stdio.read_file(
		ROOT+"/lowlib/system/cmds/shutdown_safe.pike");
	string worker = Stdio.read_file(
		ROOT+"/gamelib/single/daemons/map_workerd.pike");
	string rpc = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/map_worker_rpc.pike");
	test_start("关服只在全部玩家原子存档成功后执行");
	test_result(source &&
		search(source,"query_all_connected_players")!=-1 &&
		search(source,"http_api_daemon->vconnections")!=-1 &&
		search(source,"player->set_links(0);")!=-1 &&
		search(source,"player->set_inventory_links(0);")!=-1 &&
		search(source,"set_this_player(player);")!=-1 &&
		search(source,"set_this_player(old_context);")!=-1 &&
		search(source,"functionp(player->save_with_result)")!=-1 &&
		search(source,
			"save_ok = player->save_with_result(0,worker_shutdown ? 1 : 0);")!=-1 &&
		search(source,"shutdown_safe_ephemeral_login(player)")!=-1 &&
		search(source,"has_prefix(userid,\"logintmp\")")!=-1 &&
		search(source,"Stdio.file_size(path+\".bak\")<=0")!=-1 &&
		search(source,"shutdown_safe ABORTED")!=-1 &&
		search(source,"if(failed>0)")!=-1 &&
		search(source,"shutdown(0);")!=-1 &&
		search(source,"player->command(\"quit\")")==-1 &&
		search(worker,"cancel_local_shutdown_save_fence")!=-1 &&
		search(worker,"local_shutdown_save_fence_expires_at = 0")!=-1 &&
		search(rpc,"local_cancel_shutdown")!=-1,
		"关服流程未校验存档结果或仍会在失败后退出");
}

int main()
{
	werror("\n========== 玩家存档安全测试 ==========\n");
	test_atomic_save_and_restore();
	test_autosave_schedule_contract();
	test_persistent_activity_timer_rebuild();
	test_paid_training_worker_and_restart_recovery();
	test_ghost_worker_and_restart_recovery();
	test_shutdown_save_contract();
	werror("玩家存档安全测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
