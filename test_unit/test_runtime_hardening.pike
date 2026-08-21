#!/usr/bin/env pike
/** Worker慢路径、共享装备发布和生成源码的生产回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);
array(int) concurrent_publish_results = ({});
Thread.Mutex concurrent_publish_lock = Thread.Mutex();

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[运行加固] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[运行加固] ✗ %s: %s\n",name,detail);
	}
}

void run_concurrent_publish(string path,string source)
{
	int published = write_item_file(path,source);
	object key = concurrent_publish_lock->lock();
	concurrent_publish_results += ({published});
	destruct(key);
}

void test_item_publish_runtime()
{
	string path = ROOT+"/log/test_item_publish_safety.generated";
	string first = "protected protected void create(){\n}\n";
	string second = "void create(){\n\tint changed=1;\n}\n";
	string replacement = "void create(){\n\tint replaced=1;\n}\n";
	string saved;
	int first_ok;
	int second_ok;
	int replace_ok;
	mixed compile_err;
	rm(path);
	first_ok = write_item_file(path,first);
	second_ok = write_item_file(path,second);
	saved = Stdio.read_file(path) || "";
	compile_err = catch { compile_file(path); };
	check("首次生成原子发布、重复生成保留先到完整文件",
		first_ok && second_ok && !compile_err &&
		search(saved,"protected void create(){")!=-1 &&
		search(saved,"protected protected")==-1 &&
		search(saved,"changed")==-1,
		"同名装备可能被第二个Worker覆盖、截断或继续产生create告警");
	replace_ok = write_item_file(path,replacement,1);
	saved = Stdio.read_file(path) || "";
	check("显式覆盖也使用完整原子替换并规范create可见性",
		replace_ok && search(saved,"protected void create(){")!=-1 &&
		search(saved,"replaced=1")!=-1,
		"兼容覆盖路径可能留下半文件或公开create告警");
	rm(path);

	string concurrent_path = ROOT+
		"/log/test_item_publish_safety.concurrent";
	string source_a = "void create(){\n\tint winner=101;\n}\n";
	string source_b = "void create(){\n\tint winner=202;\n}\n";
	rm(concurrent_path);
	concurrent_publish_results = ({});
	object writer_a = Thread.Thread(run_concurrent_publish,
		concurrent_path,source_a);
	object writer_b = Thread.Thread(run_concurrent_publish,
		concurrent_path,source_b);
	writer_a->wait();
	writer_b->wait();
	saved = Stdio.read_file(concurrent_path) || "";
	check("两个并发生成线程只发布一个完整胜者且双方幂等成功",
		sizeof(concurrent_publish_results)==2 &&
		concurrent_publish_results[0] && concurrent_publish_results[1] &&
		search(saved,"protected void create(){")!=-1 &&
		((search(saved,"winner=101")!=-1 &&
		  search(saved,"winner=202")==-1) ||
		 (search(saved,"winner=202")!=-1 &&
		  search(saved,"winner=101")==-1)),
		"并发生成可能拼接、覆盖或把成功请求误报为失败");
	rm(concurrent_path);

	string lazy_path=ROOT+
		"/gamelib/clone/item/.test_runtime_lazy_normalize";
	string legacy_source="protected protected void create(){\n"+
		"\tint legacy_value=17;\n}\n";
	rm(lazy_path);
	Stdio.write_file(lazy_path,legacy_source);
	object lazy_item;
	mixed lazy_err=catch { lazy_item=clone_item(lazy_path); };
	saved=Stdio.read_file(lazy_path) || "";
	check("百万级历史物品树不全扫且旧源码在首次加载时原子修复",
		!lazy_err && lazy_item &&
		search(saved,"protected void create(){")!=-1 &&
		search(saved,"protected protected")==-1,
		sprintf("惰性修复失败 err=%O object=%d source=%O",
			lazy_err,!!lazy_item,saved));
	if(lazy_item)
		destruct(lazy_item);
	rm(lazy_path);

	string clone_path=ROOT+
		"/gamelib/clone/item/.test_runtime_clone_normalize";
	string clone_source="void create(){\n"+
		"\tint clone_value=23;\n}\n";
	rm(clone_path);
	Stdio.write_file(clone_path,clone_source);
	object clone_object;
	mixed clone_err=catch { clone_object=clone(clone_path); };
	saved=Stdio.read_file(clone_path) || "";
	check("通用clone物品入口在编译前惰性修复旧源码",
		!clone_err && clone_object &&
		search(saved,"protected void create(){")!=-1 &&
		search(saved,"\nvoid create(){")==-1,
		sprintf("clone惰性修复失败 err=%O object=%d source=%O",
			clone_err,!!clone_object,saved));
	if(clone_object)
		destruct(clone_object);
	rm(clone_path);

	string new_path=ROOT+
		"/gamelib/clone/item/.test_runtime_new_normalize";
	string new_source="protected protected void create(){\n"+
		"\tint new_value=29;\n}\n";
	rm(new_path);
	Stdio.write_file(new_path,new_source);
	object new_object;
	mixed new_err=catch { new_object=new(new_path); };
	saved=Stdio.read_file(new_path) || "";
	check("通用new物品入口在编译前惰性修复旧源码",
		!new_err && new_object &&
		search(saved,"protected void create(){")!=-1 &&
		search(saved,"protected protected")==-1,
		sprintf("new惰性修复失败 err=%O object=%d source=%O",
			new_err,!!new_object,saved));
	if(new_object)
		destruct(new_object);
	rm(new_path);

	string restore_path=ROOT+
		"/gamelib/clone/item/.test_runtime_restore_preflight";
	string restore_source="void create(){\n"+
		"\tint restore_value=31;\n}\n";
	rm(restore_path);
	Stdio.write_file(restore_path,restore_source);
	normalize_item_source_file(restore_path);
	saved=Stdio.read_file(restore_path) || "";
	object restored_item;
	mixed restore_err=catch { restored_item=(object)restore_path; };
	check("人物背包恢复在driver加载旧装备前显式规范create",
		!restore_err && restored_item &&
		search(saved,"protected void create(){")!=-1 &&
		search(saved,"\nvoid create(){")==-1,
		sprintf("恢复预检失败 err=%O object=%d source=%O",
			restore_err,!!restored_item,saved));
	if(restored_item)
		destruct(restored_item);
	rm(restore_path);

	string truncated_path=ROOT+
		"/gamelib/clone/item/.test_runtime_truncated_generated";
	string truncated_source="#include <globals.h>\n"+
		"#include <gamelib/include/gamelib.h>\n"+
		"inherit WAP_ARMOR;\n"+
		"protected void create(){\n"+
		"\tname=object_name(this_object());\n"+
		"\tname_cn=\"测试旧装备\";\n";
	rm(truncated_path);
	Stdio.write_file(truncated_path,truncated_source);
	normalize_item_source_file(truncated_path);
	saved=Stdio.read_file(truncated_path) || "";
	object truncated_item;
	mixed truncated_err=catch { truncated_item=(object)truncated_path; };
	check("历史生成装备恰好缺失末尾大括号时惰性保守修复",
		!truncated_err && truncated_item && has_suffix(saved,"}\n") &&
		sizeof(saved)>sizeof(truncated_source),
		sprintf("截断装备修复失败 err=%O object=%d source=%O",
			truncated_err,!!truncated_item,saved));
	if(truncated_item)
		destruct(truncated_item);
	rm(truncated_path);
}

int main()
{
	string efuns = Stdio.read_file(ROOT+"/lowlib/efuns.pike") || "";
	string items = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/itemsd.pike") || "";
	string boss = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/bossdropd.pike") || "";
	string skill = Stdio.read_file(ROOT+"/gamelib/single/create_skill.pike") || "";
	string mapd = Stdio.read_file(ROOT+"/gamelib/single/daemons/mapd.pike") || "";
	string store = Stdio.read_file(ROOT+
		"/lowlib/mudlib/single/specstored.pike") || "";
	string save_feature = Stdio.read_file(ROOT+
		"/lowlib/system/inherit/feature/save.pike") || "";
	mixed get_compile_err = catch {
		compile_file(ROOT+"/gamelib/cmds/get.pike");
	};
	mixed vendue_compile_err = catch {
		compile_file(ROOT+"/gamelib/cmds/vendue_cancel.pike");
	};
	object|zero fly_command;
	mixed fly_compile_err = catch {
		fly_command=(object)(ROOT+
			"/gamelib/cmds/home_function_fly_show_target.pike");
	};
	array(string) create_sources = ({
		"/lowlib/conn.pike",
		"/gamelib/clone/user.pike",
		"/lowlib/system/inherit/filter.pike",
		"/lowlib/system/master.pike",
		"/lowlib/system/single/void.pike",
		"/lowlib/wapmud2/inherit/npc.pike",
		"/lowlib/wapmud2/inherit/user.pike",
		"/lowlib/wapmud2/single/honerd.pike",
	});
	int clean_create_sources = 1;
	foreach(create_sources,string source_path){
		string source = Stdio.read_file(ROOT+source_path) || "";
		if(source=="" || search(source,"protected protected")!=-1 ||
		   search(source,"protected void create(")==-1 ||
		   search(source,"\nvoid create(")!=-1)
			clean_create_sources = 0;
	}

	check("共享装备文件通过跨进程锁和同目录临时文件发布",
		search(efuns,"item_publish_locks")!=-1 &&
		search(efuns,"mkdir(lock_path)")!=-1 &&
		search(efuns,"mv(temp_path,file)")!=-1 &&
		search(efuns,"Stdio.file_size(file)>0")!=-1,
		"多Worker仍可能同时截断同一装备源码");
	check("历史生成装备按首次加载惰性修复且检查缓存有界",
		search(efuns,"normalize_existing_item_source(path)")!=-1 &&
		search(efuns,"void normalize_item_source_file(string file)")!=-1 &&
		search(efuns,"ITEM_SOURCE_CHECK_CACHE_LIMIT 16384")!=-1 &&
		search(efuns,"write_item_file(file,normalized,1)")!=-1 &&
		search(save_feature,"normalize_item_source_file(final_path);")!=-1 &&
		search(save_feature,"object ob=clone(final_path);")>
			search(save_feature,"normalize_item_source_file(final_path);"),
		"重启仍可能全量扫描百万物品，或每次克隆都重复读取源码");
	check("所有装备与技能生成入口在写盘前统一规范create",
		search(efuns,"normalize_generated_item_source")!=-1 &&
		search(items,"write_item_file(ITEM_PATH+item_name,writeback)")!=-1 &&
		search(boss,"write_item_file(ITEM_PATH+item_name,writeback)")!=-1 &&
		search(skill,"templates[\"head\"]=\"protected void create(){")!=-1,
		"仍有生成入口会制造公开或重复protected的create函数");
	check("核心继承链create修饰符恰好保留一个protected",
		clean_create_sources,
		"重复修饰符会污染每个Worker的编译日志并掩盖真实告警");
	check("地图预览复用静态房间且缓存按对象路径隔离",
		search(mapd,"clone(room_path)")==-1 &&
		search(mapd,"object_name(pre_room)")!=-1 &&
		search(mapd,"search(room_key,\"#\")")!=-1 &&
		search(mapd,"room_stat->isdir")!=-1 &&
		search(mapd,"destruct(next_room)")==-1,
		"每次首次看地图仍会克隆20个带心跳/怪物的房间");
	check("神秘商店每个普通装备格只生成一个候选并及时销毁临时对象",
		search(store,"query_random_goods_normal")!=-1 &&
		search(store,"destruct(obt)")!=-1 &&
		search(store,"query_goods_list_normal(random(71)+1)")==-1,
		"一次刷新仍会批量生成并遗留大量未使用装备对象");
	check("生产历史报错的拾取与取消拍卖命令保持可编译",
		!get_compile_err && !vendue_compile_err,
		"get或vendue_cancel再次出现Cpp/对象加载失败");
	string valid_fly_target=ROOT+"/gamelib/d/congxianzhen/xiaomuwu";
	check("家园飞行命令可编译且只接受静态地图树内目的地",
		!fly_compile_err && fly_command &&
		fly_command->normalize_home_fly_target(valid_fly_target)==
			valid_fly_target &&
		fly_command->home_fly_target_command_arg(valid_fly_target)==
			"congxianzhen/xiaomuwu" &&
		fly_command->normalize_home_fly_target(
			ROOT+"/gamelib/d/../single/daemons/homed.pike")=="" &&
		fly_command->normalize_home_fly_target(
			ROOT+"/gamelib/d/congxianzhen/xiaomuwu#7")=="" &&
		fly_command->normalize_home_fly_target("/tmp/not-a-map")=="",
		sprintf("飞行命令编译或路径白名单失败 err=%O",fly_compile_err));

	test_item_publish_runtime();
	werror("运行加固：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"] ? 1 : 0;
}
