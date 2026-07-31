#!/usr/bin/env pike
/**
 * Docker MUD 启动堆栈静态契约测试。
 *
 * 覆盖：
 * - 容器运行层开放 Linux 进程栈
 * - 镜像启动脚本开放 Linux 进程栈
 * - Pike evaluator 栈设为 1000000
 * - Pike 线程栈设为 64 MiB
 * - 部署时先同步外置 item 目录再启动容器
 * - 方士阵营图标与人物头像同步到容器项目和 Tomcat 的所有访问路径
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

void test_item_sync_contract()
{
	test_start("部署时同步并校验容器外置物品");
	string source =
		Stdio.read_file(ROOT+"/restart-docker.sh");
	int sync_position = -1;
	int run_position = -1;
	int hidden_count = 0;
	array(string) hidden_ids = ({
		"wanjianguizong","taiqingjianyu","pozhenjianyi",
		"taixulingyun","wanlingchaosheng","sixiangfengjin",
		"jiutianleiyin","taiyixuanguang","bingpochanshen",
		"zhutianwujie","tianshajianyi","wuyingfenghou",
		"xuemoshijie","shurakuangyi","xuehailieshang",
		"huangquanwudu","wanxiangshihun","jiuyouduzhang",
		"wuyingjuemie","jiuyouguibu","liudaozhangmu",
	});

	if(source){
		sync_position = search(source,"\n    sync_item_directory\n");
		run_position = search(source,"\n    docker run -d");
		foreach(hidden_ids,string skill_id)
			if(search(source,"\""+skill_id+"\"")!=-1)
				hidden_count++;
	}
	if(source &&
	   search(source,"local commands=(\"docker\" \"rsync\")")!=-1 &&
	   search(source,
		   "rsync -a \"$source_item_dir/\" \"$shared_item_dir/\"")!=-1 &&
	   search(source,
		   "$shared_item_dir/book/huling1")!=-1 &&
	   hidden_count==21 &&
	   search(source,
		   "verify_hidden_mythic_assets_in_container")!=-1 &&
	   search(source,
		   "test -s \"/app/xiand/gamelib/single/skills/$skill_id\"")!=-1 &&
	   search(source,
		   "grep -Fq \"\\\"book/$skill_id\\\"\"")!=-1 &&
	   search(source,
		   "-v \"${SHARED_ITEM_DIR}:/app/xiand/gamelib/clone/item\"")!=-1 &&
	   sync_position!=-1 && run_position!=-1 &&
	   sync_position<run_position)
		test_pass();
	else
		test_fail("item必须同步到实际挂载目录，并校验huling1及21套隐藏传承");
}

void test_fangshi_images_deploy_contract()
{
	test_start("部署方士阵营图标与人物头像到容器全部路径");
	string source =
		Stdio.read_file(ROOT+"/restart-docker.sh");
	string source_third =
		Stdio.read_file(ROOT+"/images/third_logo.png");
	string web_third =
		Stdio.read_file(ROOT+"/web/images/third_logo.png");
	string source_logo =
		Stdio.read_file(ROOT+"/images/human_fangshi_logo.png");
	string web_logo =
		Stdio.read_file(ROOT+"/web/images/human_fangshi_logo.png");
	string source_male =
		Stdio.read_file(ROOT+"/images/human_fangshi_male.png");
	string web_male =
		Stdio.read_file(ROOT+"/web/images/human_fangshi_male.png");
	string source_female =
		Stdio.read_file(ROOT+"/images/human_fangshi_female.png");
	string web_female =
		Stdio.read_file(ROOT+"/web/images/human_fangshi_female.png");

	if(source && source_third && web_third &&
	   source_logo && web_logo &&
	   source_male && web_male &&
	   source_female && web_female &&
	   source_third==web_third &&
	   source_logo==web_logo &&
	   source_male==web_male &&
	   source_female==web_female &&
	   source_logo!=source_male &&
	   source_logo!=source_female &&
	   source_male!=source_female &&
	   search(source,
		   "\"human_fangshi_logo.png\"")!=-1 &&
	   search(source,
		   "\"human_fangshi_male.png\"")!=-1 &&
	   search(source,
		   "\"human_fangshi_female.png\"")!=-1 &&
	   search(source,
		   "copy_fangshi_images_to_container \"$CONTAINER_NAME\"")!=-1 &&
	   search(source,
		   "test -s \"$app_root/images/$image_name\"")!=-1 &&
	   search(source,
		   "test -s \"$app_root/web/images/$image_name\"")!=-1 &&
	   search(source,
		   "test -s \"$tomcat_root/images/$image_name\"")!=-1 &&
	   search(source,
		   "test -s \"$tomcat_root/xd/images/$image_name\"")!=-1)
		test_pass();
	else
		test_fail("方士图片必须镜像一致、男女有别并部署到容器全部路径");
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
	test_item_sync_contract();
	test_fangshi_images_deploy_contract();
	print_summary();
	if(test_results["failed"]==0)
		return 0;
	return 1;
}
