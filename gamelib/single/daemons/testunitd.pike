#!/usr/bin/env pike
/**
 * 单元测试守护进程
 * 启动后动态发现并运行 test_unit/test_*.pike。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

mapping tests_status = ([]);

private int testunit_archive_filename(string filename)
{
	string lower = lower_case(filename || "");
	if(search(lower,"testunit")==-1)
		return 0;
	return has_suffix(lower,".o") || has_suffix(lower,".o.bak") ||
		has_suffix(lower,".o.tmp") || has_suffix(lower,".o.bak.tmp");
}

private int cleanup_testunit_player_archives()
{
	string user_root = DATA_ROOT+"u";
	int removed;
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return 0;
	foreach(get_dir(user_root) || ({}),string bucket){
		string directory = user_root+"/"+bucket;
		if(Stdio.file_size(directory)!=-2)
			continue;
		foreach(get_dir(directory) || ({}),string filename){
			string path = directory+"/"+filename;
			if(testunit_archive_filename(filename) &&
			   Stdio.file_size(path)>=0 && rm(path))
				removed++;
		}
	}
	return removed;
}

void run_all_tests()
{
	string test_dir = ROOT + "/test_unit";
	array(string)|zero all_files = get_dir(test_dir);
	array(string) test_files = ({});
	int total_passed = 0;
	int total_failed = 0;
	int total_skipped = 0;

	werror("\n╔════════════════════════════════════════════════════════════╗\n");
	werror("║              单元测试守护进程 (TestUnitD)                  ║\n");
	werror("╚════════════════════════════════════════════════════════════╝\n\n");

	if(!all_files){
		werror("[TESTUNITD] ERROR 无法读取测试目录: %s\n", test_dir);
		total_failed = 1;
	}
	else{
		foreach(all_files, string file_name){
			if(has_prefix(file_name, "test_") &&
			   has_suffix(file_name, ".pike") &&
			   file_name != "test_framework.pike"){
				test_files += ({file_name});
			}
		}
		sort(test_files);
	}

	werror("[TESTUNITD] START discovered=%d\n", sizeof(test_files));
	werror("[TESTUNITD] CLEANUP phase=start removed=%d\n",
		cleanup_testunit_player_archives());

	foreach(test_files, string test_file){
		string test_path = test_dir + "/" + test_file;
		string source = Stdio.read_file(test_path);
		int result = 1;
		int runnable = source && search(source, "int main") != -1;
		mixed err = 0;

		if(!runnable){
			werror("[TESTUNITD] SKIP %s (辅助脚本，无 main)\n", test_file);
			total_skipped++;
			continue;
		}

		werror("\n[TESTUNITD] RUN %s\n", test_file);
		err = catch {
			program test_program = (program)test_path;
			if(test_program){
				object test_object = test_program();
				if(test_object && functionp(test_object->main))
					result = test_object->main();
			}
		};

		if(err){
			werror("[TESTUNITD] FAIL %s exception=%s\n",
				test_file, describe_error(err));
			werror("[TESTUNITD] BACKTRACE %s\n", describe_backtrace(err));
			total_failed++;
		}
		else if(result == 0){
			werror("[TESTUNITD] PASS %s\n", test_file);
			total_passed++;
		}
		else{
			werror("[TESTUNITD] FAIL %s result=%d\n", test_file, result);
			total_failed++;
		}
	}

	werror("\n╔════════════════════════════════════════════════════════════╗\n");
	werror("║ 单元测试完成 - 通过: %d, 失败: %d, 跳过: %d                ║\n",
		total_passed, total_failed, total_skipped);
	werror("╚════════════════════════════════════════════════════════════╝\n");
	werror("[TESTUNITD] COMPLETE passed=%d failed=%d skipped=%d\n\n",
		total_passed, total_failed, total_skipped);
	mixed cleanup_gc_error = catch{ gc(); };
	if(cleanup_gc_error)
		werror("[TESTUNITD] CLEANUP gc_error=%s\n",
			describe_error(cleanup_gc_error));
	werror("[TESTUNITD] CLEANUP phase=end removed=%d\n",
		cleanup_testunit_player_archives());

	tests_status["last_run"] = time();
	tests_status["total_passed"] = total_passed;
	tests_status["total_failed"] = total_failed;
	tests_status["total_skipped"] = total_skipped;
	tests_status["total_tests"] = total_passed + total_failed;
}

mapping get_status()
{
	return tests_status;
}

protected void create()
{
	string node_role = lower_case(getenv("XIAND_NODE_ROLE") || "standalone");
	if(getenv("XIAND_RUN_TESTUNIT")!="1"){
		werror("[TESTUNITD] SKIP disabled node role=%s\n",node_role);
		return;
	}
	werror("[TESTUNITD] 单元测试守护进程启动\n");
	call_out(run_all_tests, 3);
}
