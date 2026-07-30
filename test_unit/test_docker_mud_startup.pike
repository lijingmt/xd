#!/usr/bin/env pike
/**
 * Docker MUD 启动堆栈静态契约测试。
 *
 * 覆盖：
 * - 容器运行层开放 Linux 进程栈
 * - 镜像启动脚本开放 Linux 进程栈
 * - Pike evaluator 栈设为 1000000
 * - Pike 线程栈设为 64 MiB
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
	werror("\n[Docker MUD启动 %d] %s\n",test_results["total"],name);
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

void test_container_stack_contract()
{
	test_start("Docker运行层开放系统栈");
	string compose_source =
		Stdio.read_file(ROOT+"/docker/docker-compose.yml");
	string restart_source =
		Stdio.read_file(ROOT+"/restart-docker.sh");

	if(compose_source && restart_source &&
	   search(compose_source,"stack:")!=-1 &&
	   search(compose_source,"soft: -1")!=-1 &&
	   search(compose_source,"hard: -1")!=-1 &&
	   search(restart_source,"--ulimit stack=-1:-1")!=-1)
		test_pass();
	else
		test_fail("compose或docker run缺少无限系统栈配置");
}

void test_pike_stack_contract()
{
	test_start("镜像内MUD使用放大的Pike内部栈");
	string source =
		Stdio.read_file(ROOT+"/docker/Dockerfile.all");
	string command =
		"pike -s1000000 -ss67108864 "+
		"/app/xiand/lowlib/driver.pike";

	if(source &&
	   search(source,"ulimit -s unlimited")!=-1 &&
	   search(source,command)!=-1)
		test_pass();
	else
		test_fail("MUD启动命令缺少系统栈、evaluator栈或64MiB线程栈");
}

void test_stack_order_contract()
{
	test_start("堆栈设置先于Pike MUD启动");
	string source =
		Stdio.read_file(ROOT+"/docker/Dockerfile.all");
	int ulimit_position = -1;
	int pike_position = -1;

	if(source){
		ulimit_position = search(source,"ulimit -s unlimited");
		pike_position = search(source,
			"pike -s1000000 -ss67108864");
	}
	if(ulimit_position!=-1 && pike_position!=-1 &&
	   ulimit_position<pike_position)
		test_pass();
	else
		test_fail("系统栈必须在Pike进程创建前放开");
}

void print_summary()
{
	werror("\n========================================\n");
	werror("Docker MUD启动测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],
		test_results["passed"],
		test_results["failed"]);
	werror("========================================\n");
}

int main()
{
	test_container_stack_contract();
	test_pike_stack_contract();
	test_stack_order_contract();
	print_summary();
	if(test_results["failed"]==0)
		return 0;
	return 1;
}
