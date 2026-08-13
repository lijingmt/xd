#!/usr/bin/env pike
/** 历史零级装备熔解空产物保护回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

int failures=0;

void check(string name,int valid,string detail)
{
	if(valid)
		werror("[熔解空产物保护] ✓ %s\n",name);
	else{
		failures++;
		werror("[熔解空产物保护] ✗ %s: %s\n",name,detail);
	}
}

void test_zero_level_result_and_command_guard()
{
	object daemon=(object)(ROOT+"/gamelib/single/daemons/rongjied.pike");
	array(object) products=({});
	mixed err=catch {
		products=daemon->get_rongjie_items(0,3);
	};
	check("零级历史装备没有配置产物时返回空数组",
		!err && arrayp(products) && sizeof(products)==0,
		err ? describe_error(err) : sprintf("products=%O",products));

	string source=Stdio.read_file(ROOT+
		"/gamelib/cmds/viceskill_rongjie_confirm.pike");
	int guard_pos=source ? search(source,"if(!sizeof(get_items) || !objectp(get_items[0]))") : -1;
	int index_pos=source ? search(source,"kuang = get_items[0]") : -1;
	check("命令在读取首个产物前拦截空数组",
		source && guard_pos>=0 && index_pos>guard_pos &&
		search(source,"装备没有被消耗")>=0 &&
		search(source,"sscanf(arg,\"%d %s %d\",flag,name,count)!=3")>=0,
		"空结果保护缺失或位于数组读取之后");
}

void test_changed_files_compile()
{
	foreach(({
		"/gamelib/cmds/viceskill_rongjie_confirm.pike",
		"/gamelib/single/daemons/rongjied.pike"
	}),string file){
		mixed err=catch { compile_file(ROOT+file); };
		check(file+" 可编译",!err,err ? describe_error(err) : "");
	}
}

int main()
{
	werror("\n========== 熔解空产物保护测试 ==========\n");
	test_zero_level_result_and_command_guard();
	test_changed_files_compile();
	werror("熔解空产物保护测试：失败 %d\n",failures);
	return failures ? 1 : 0;
}
