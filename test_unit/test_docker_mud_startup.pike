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

void test_pike_version_contract()
{
	test_start("Docker构建固定使用Pike 9.0.13并验证关键模块");
	string source =
		Stdio.read_file(ROOT+"/docker/Dockerfile.all");

	if(source &&
	   search(source,"ARG PIKE_VERSION=9.0.13")!=-1 &&
	   search(source,
		   "Pike-v${PIKE_VERSION}.tar.gz")!=-1 &&
	   search(source,"--retry 5")!=-1 &&
	   search(source,
		   "gzip -t \"Pike-v${PIKE_VERSION}.tar.gz\"")!=-1 &&
	   search(source,"--with-mysql")!=-1 &&
	   search(source,"master()->resolv(\"Sql\")")!=-1 &&
	   search(source,"master()->resolv(\"SSL\")")!=-1 &&
	   search(source,"master()->resolv(\"Crypto\")")!=-1)
		test_pass();
	else
		test_fail("Pike版本、可靠下载或MySQL/SSL/Crypto模块验证不完整");
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
		"wanshanchaogong","buzhouzhenji","tiandichengbi",
		"xinghezhuiluo","zhoutianjingzhi","wanxiangxingbi",
		"cixinpudu","huimingtianlu","wanmuxinchun",
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
	   hidden_count==30 &&
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
		test_fail("item必须同步到实际挂载目录，并校验huling1及30套隐藏传承");
}

void test_neutral_profession_images_deploy_contract()
{
	test_start("部署中立阵营四职业图标与人物头像到容器全部路径");
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
	string tianxiang_logo =
		Stdio.read_file(ROOT+"/images/tianxiang_logo.png");
	string tianxiang_web_logo =
		Stdio.read_file(ROOT+"/web/images/tianxiang_logo.png");
	string tianxiang_male =
		Stdio.read_file(ROOT+"/images/tianxiang_male.png");
	string tianxiang_web_male =
		Stdio.read_file(ROOT+"/web/images/tianxiang_male.png");
	string tianxiang_female =
		Stdio.read_file(ROOT+"/images/tianxiang_female.png");
	string tianxiang_web_female =
		Stdio.read_file(ROOT+"/web/images/tianxiang_female.png");
	string lingyi_logo =
		Stdio.read_file(ROOT+"/images/lingyi_logo.png");
	string lingyi_web_logo =
		Stdio.read_file(ROOT+"/web/images/lingyi_logo.png");
	string lingyi_male =
		Stdio.read_file(ROOT+"/images/lingyi_male.png");
	string lingyi_web_male =
		Stdio.read_file(ROOT+"/web/images/lingyi_male.png");
	string lingyi_female =
		Stdio.read_file(ROOT+"/images/lingyi_female.png");
	string lingyi_web_female =
		Stdio.read_file(ROOT+"/web/images/lingyi_female.png");

	if(source && source_third && web_third &&
	   source_logo && web_logo &&
	   source_male && web_male &&
	   source_female && web_female &&
	   tianxiang_logo && tianxiang_web_logo &&
	   tianxiang_male && tianxiang_web_male &&
	   tianxiang_female && tianxiang_web_female &&
	   lingyi_logo && lingyi_web_logo &&
	   lingyi_male && lingyi_web_male &&
	   lingyi_female && lingyi_web_female &&
	   source_third==web_third &&
	   source_logo==web_logo &&
	   source_male==web_male &&
	   source_female==web_female &&
	   source_logo!=source_male &&
	   source_logo!=source_female &&
	   source_male!=source_female &&
	   tianxiang_logo==tianxiang_web_logo &&
	   tianxiang_male==tianxiang_web_male &&
	   tianxiang_female==tianxiang_web_female &&
	   tianxiang_logo!=tianxiang_male &&
	   tianxiang_logo!=tianxiang_female &&
	   tianxiang_male!=tianxiang_female &&
	   lingyi_logo==lingyi_web_logo &&
	   lingyi_male==lingyi_web_male &&
	   lingyi_female==lingyi_web_female &&
	   lingyi_logo!=lingyi_male &&
	   lingyi_logo!=lingyi_female &&
	   lingyi_male!=lingyi_female &&
	   search(source,
		   "\"human_fangshi_logo.png\"")!=-1 &&
	   search(source,
		   "\"human_fangshi_male.png\"")!=-1 &&
	   search(source,
		   "\"human_fangshi_female.png\"")!=-1 &&
	   search(source,"\"tianxiang_logo.png\"")!=-1 &&
	   search(source,"\"tianxiang_male.png\"")!=-1 &&
	   search(source,"\"tianxiang_female.png\"")!=-1 &&
	   search(source,"\"lingyi_logo.png\"")!=-1 &&
	   search(source,"\"lingyi_male.png\"")!=-1 &&
	   search(source,"\"lingyi_female.png\"")!=-1 &&
	   search(source,
	   "copy_neutral_profession_images_to_container \"$CONTAINER_NAME\"")!=-1 &&
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
		test_fail("中立职业图片必须镜像一致、男女有别并部署到容器全部路径");
}

void test_local_restart_save_contract()
{
	test_start("本地重启先执行游戏内全员存档再停止进程");
	string source = Stdio.read_file(
		ROOT+"/scripts/restart_with_testunit.sh");
	int graceful_position = -1;
	int fail_position = -1;
	if(source){
		graceful_position = search(source,
			"if ! graceful_shutdown; then");
		fail_position = search(source,
			"in-game shutdown did not confirm all player saves");
	}
	if(source &&
	   search(source,"printf 'shutdown_safe\\r\\n'")!=-1 &&
	   search(source,
		   "requesting in-game shutdown so online players are saved")!=-1 &&
	   search(source,
		   "refusing an unsafe forced restart")!=-1 &&
	   graceful_position!=-1 && fail_position!=-1 &&
	   graceful_position<fail_position &&
	   search(source,
		   "if ! graceful_shutdown; then\n\t\tstop_port_processes") == -1)
		test_pass();
	else
		test_fail("restart必须先通过MUD shutdown保存在线玩家，失败时不得TERM");
}

void test_local_restart_stack_contract()
{
	test_start("本地开发重启与容器使用相同Pike内部栈");
	string source = Stdio.read_file(
		ROOT+"/scripts/restart_with_testunit.sh");
	if(source &&
	   search(source,"XIAND_PIKE_STACK_DEPTH:-1000000")!=-1 &&
	   search(source,"XIAND_PIKE_THREAD_STACK:-67108864")!=-1 &&
	   search(source,"-s'$PIKE_STACK_DEPTH' -ss'$PIKE_THREAD_STACK'")!=-1 &&
	   search(source,"PIKE_STACK_DEPTH <= 0")!=-1 &&
	   search(source,"PIKE_THREAD_STACK <= 0")!=-1 &&
	   search(source,"Pike stack settings must be positive integers")!=-1)
		test_pass();
	else
		test_fail("本地重启缺少可校验的evaluator栈或64MiB线程栈");
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
	test_pike_version_contract();
	test_stack_order_contract();
	test_item_sync_contract();
	test_neutral_profession_images_deploy_contract();
	test_local_restart_save_contract();
	test_local_restart_stack_contract();
	print_summary();
	if(test_results["failed"]==0)
		return 0;
	return 1;
}
