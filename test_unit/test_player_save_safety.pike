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
	test_shutdown_save_contract();
	werror("玩家存档安全测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
