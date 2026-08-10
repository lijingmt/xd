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
		Stdio.read_file(ROOT+"/docker/start-unified.sh");
	if(source &&
	   search(source,"ulimit -s unlimited")!=-1 &&
	   search(source,"pike -s1000000 -ss67108864")!=-1 &&
	   search(source,"-ss67108864 --no-precompile")!=-1 &&
	   search(source,"\"$ROOT_DIR/lowlib/driver.pike\"")!=-1)
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
		Stdio.read_file(ROOT+"/docker/start-unified.sh");
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
		"cixinpudu","huimingtianlu","wanmuxinchun","liuhehuichun",
		"wuxiangguixu","wuxianghunyuan","wuxiangwuji",
	});

	if(source){
		sync_position = search(source,"\n    sync_item_directory\n");
		run_position = search(source,"\n    if docker run -d");
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
	   hidden_count==34 &&
	   search(source,"load_ancient_hidden_skill_ids")!=-1 &&
	   search(source,"ANCIENT_SKILL_CATALOG")!=-1 &&
	   search(source,"ANCIENT_HIDDEN_SKILL_IDS")!=-1 &&
	   search(source,"-ne 70")!=-1 &&
	   search(source,"缺少太古隐藏秘籍")!=-1 &&
	   search(source,"ancient_skilld.pike")!=-1 &&
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
		test_fail("item必须同步到实际挂载目录，并校验huling1、34套原隐藏传承及70套太古传承");
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

void test_real_healthcheck_and_runtime_contracts()
{
	test_start("容器健康检查访问真实HTTP且运行时静态契约可见");
	string dockerfile = Stdio.read_file(ROOT+"/docker/Dockerfile.all");
	string ignore = Stdio.read_file(ROOT+"/.dockerignore");
	string startup = Stdio.read_file(ROOT+"/docker/start-unified.sh");
	string message_daemon = Stdio.read_file(
		ROOT+"/gamelib/single/daemons/messaged.pike");
	if(dockerfile && ignore && startup && message_daemon &&
	   search(dockerfile,"curl -fsS --max-time 5")!=-1 &&
	   search(dockerfile,"http://127.0.0.1:8888/health")!=-1 &&
	   search(dockerfile,"CMD pike -e 'exit(0);'")==-1 &&
	   search(startup,"\"$ROOT_DIR/log/fee_log\"")!=-1 &&
	   search(startup,"\"$ROOT_DIR/log/home/drop\"")!=-1 &&
	   search(startup,"\"$ROOT_DIR/log/stat/online\"")!=-1 &&
	   search(startup,"\"$ROOT_DIR/db_log/reg_new\"")!=-1 &&
	   search(startup,"\"$ROOT_DIR/db_log/daily_user\"")!=-1 &&
	   search(message_daemon,"Stdio.file_size(MSG_LIST)<=0")!=-1 &&
	   search(message_daemon,"if(!msgData)")!=-1 &&
	   search(ignore,"!docker/Dockerfile.all")!=-1 &&
	   search(ignore,"!docker/docker-compose.yml")!=-1 &&
	   search(ignore,"!docker/start-unified.sh")!=-1 &&
	   search(ignore,"!.env.example")!=-1 &&
	   search(dockerfile,
		   "COPY docker/start-unified.sh /app/start-unified.sh")!=-1 &&
	   search(startup,"chmod 700 \"$ROOT_DIR/db_log\"")!=-1)
		test_pass();
	else
		test_fail("健康检查可能假阳性、运行目录/空公告兼容不全或镜像TestUnit缺文件");
}

void test_worker_docker_start_chain_contract()
{
	test_start("restart-all到容器的可配置worker启动链完整");
	string wrapper = Stdio.read_file(ROOT+"/restart-all-docker.sh");
	string restart = Stdio.read_file(ROOT+"/restart-docker.sh");
	string compose = Stdio.read_file(ROOT+"/docker/docker-compose.yml");
	string dockerfile = Stdio.read_file(ROOT+"/docker/Dockerfile.all");
	string startup = Stdio.read_file(ROOT+"/docker/start-unified.sh");
	string bootstrap = Stdio.read_file(
		ROOT+"/scripts/bootstrap_map_worker_runtime.sh");
	string env_setup = Stdio.read_file(
		ROOT+"/scripts/setup_deploy_env.sh");
	string env_example = Stdio.read_file(ROOT+"/.env.example");
	if(wrapper && restart && compose && dockerfile && startup && bootstrap &&
	   env_setup && env_example &&
	   search(wrapper,"exec \"$SCRIPT_DIR/restart-docker.sh\"")!=-1 &&
	   search(wrapper,"xd01-02 2002 2003")!=-1 &&
	   search(wrapper,"\"$@\"")!=-1 &&
	   search(restart,"--workers")!=-1 &&
	   search(restart,"XIAND_MAP_WORKER_COUNT_OVERRIDE")!=-1 &&
	   search(restart,"\"$ENV_SETUP_SCRIPT\" \"$XIAND_ENV_FILE\"")!=-1 &&
	   search(restart,"stop_existing_container_safely")!=-1 &&
	   search(restart,"map_worker_cluster.sh stop")!=-1 &&
	   search(restart,"docker stop -t 600")!=-1 &&
	   search(restart,"--restart unless-stopped")!=-1 &&
	   search(restart,"--stop-timeout 600")!=-1 &&
	   search(restart,"prepare_map_worker_runtime")!=-1 &&
	   search(restart,
		   "/usr/local/games/allxd/${GAME_AREA}/data_xiand/map_workers")!=-1 &&
	   search(restart,"bootstrap_map_worker_runtime.sh")!=-1 &&
	   search(restart,"-e XIAND_WORKER_TOKEN")!=-1 &&
	   search(restart,"-e XIAND_MAP_WORKER_COUNT")!=-1 &&
	   search(restart,"verify_map_worker_runtime_in_container")!=-1 &&
	   search(restart,"-p \"18880") == -1 &&
	   search(restart,"-p \"18881") == -1 &&
	   search(restart,"-p \"14801") == -1 &&
	   search(compose,"XIAND_MAP_WORKER_COUNT=${XIAND_MAP_WORKER_COUNT:-3}")!=-1 &&
	   search(compose,"XIAND_WORKER_TOKEN=${XIAND_WORKER_TOKEN}")!=-1 &&
	   search(compose,"stop_grace_period: 10m")!=-1 &&
	   search(compose,"18880:") == -1 &&
	   search(compose,"18881:") == -1 &&
	   search(compose,"14801:") == -1 &&
	   search(dockerfile,"python3")!=-1 &&
	   search(dockerfile,"openssl")!=-1 &&
	   search(dockerfile,"nmap-ncat")!=-1 &&
	   search(dockerfile,"COPY . /app/xiand/")!=-1 &&
	   search(env_setup,"cp \"$ENV_TEMPLATE\" \"$ENV_FILE\"")!=-1 &&
	   search(env_setup,"chmod 600 \"$ENV_FILE\"")!=-1 &&
	   search(env_setup,"openssl rand -hex 32")!=-1 &&
	   search(env_example,"MYSQL_PASSWORD=")!=-1 &&
	   search(dockerfile,"procps-ng")!=-1 &&
	   search(startup,"XIAND_MAP_WORKER_LAUNCHER=background")!=-1 &&
	   search(startup,"\"$ROOT_DIR/data_xiand/u\"")!=-1 &&
	   search(startup,"\"$ROOT_DIR/data_xiand/accounts\"")!=-1 &&
	   search(startup,
		   "[[ \"$MAP_WORKER_CONFIG\" == \"$MAP_WORKER_DIR/config.json\" ]]")!=-1 &&
	   search(startup,"\"$MAP_WORKER_SCRIPT\" apply")!=-1 &&
	   search(startup,"start_shadow_authority")!=-1 &&
	   search(startup,"start_active_authority")!=-1 &&
	   search(bootstrap,"XIAND_MAP_WORKER_COUNT:-3")!=-1 &&
	   search(bootstrap,"chmod 600 \"$CONFIG_FILE\"")!=-1)
		test_pass();
	else
		test_fail("worker数量参数未持久化、环境未传入容器或入口未实际apply");
}

void test_local_worker_restart_chain_contract()
{
	test_start("本地一键重启先跑完整TestUnit再启动可配置worker");
	string wrapper = Stdio.read_file(ROOT+"/restart-local-workers.sh");
	string local_restart = Stdio.read_file(
		ROOT+"/scripts/restart_map_workers_with_testunit.sh");
	string testunit_restart = Stdio.read_file(
		ROOT+"/scripts/restart_with_testunit.sh");
	if(wrapper && local_restart && testunit_restart &&
	   search(wrapper,"restart_map_workers_with_testunit.sh")!=-1 &&
	   search(wrapper,"\"$@\"")!=-1 &&
	   search(local_restart,"XIAND_STOP_AFTER_TESTUNIT=1")!=-1 &&
	   search(local_restart,"\"$CLUSTER_SCRIPT\" stop")!=-1 &&
	   search(local_restart,"XIAND_MAP_WORKER_RUN_SELFTESTS=1")!=-1 &&
	   search(local_restart,"\"$CLUSTER_SCRIPT\" start \"$@\"")!=-1 &&
	   search(local_restart,"\"$CLUSTER_SCRIPT\" health")!=-1 &&
	   search(testunit_restart,"stop_after_testunit_if_requested")!=-1 &&
	   search(testunit_restart,"validated standalone could not shut down safely")!=-1)
		test_pass();
	else
		test_fail("本地worker重启可能漏跑TestUnit、漏安全停旧拓扑或忽略数量参数");
}

void test_testunit_and_include_isolation_contract()
{
	test_start("TestUnit显式启用且多Pike进程隔离编译目录");
	string test_daemon = Stdio.read_file(
		ROOT+"/gamelib/single/daemons/testunitd.pike");
	string local_restart = Stdio.read_file(
		ROOT+"/scripts/restart_with_testunit.sh");
	string cluster = Stdio.read_file(ROOT+"/scripts/map_worker_cluster.sh");
	string startup = Stdio.read_file(ROOT+"/docker/start-unified.sh");
	string driver = Stdio.read_file(ROOT+"/lowlib/driver.pike");
	if(test_daemon && local_restart && cluster && startup && driver &&
	   search(test_daemon,"getenv(\"XIAND_RUN_TESTUNIT\")!=\"1\"")!=-1 &&
	   search(local_restart,"XIAND_RUN_TESTUNIT=1")!=-1 &&
	   search(startup,"XIAND_RUN_TESTUNIT=0")!=-1 &&
	   search(startup,"-ss67108864 --no-precompile")!=-1 &&
	   search(local_restart,"--no-precompile '$ROOT_DIR/lowlib/driver.pike'")!=-1 &&
	   search(cluster,"--no-precompile '$ROOT_DIR/lowlib/driver.pike'")!=-1 &&
	   search(driver,"runtime_include_path=\"/tmp/xiand-include-\"")!=-1 &&
	   search(driver,"Stdio.recursive_rm(runtime_include_path)")!=-1 &&
	   search(driver,"add_include_path(runtime_include_path)")!=-1 &&
	   search(driver,"Stdio.recursive_rm(mudlib_root+\"/.include\")")==-1)
		test_pass();
	else
		test_fail("生产回退可能误跑TestUnit或多个Pike进程竞争.include目录");
}

void test_legacy_jsp_worker_gateway_contract()
{
	test_start("旧JSP书签和txd透明转发到Pike Gateway");
	string proxy = Stdio.read_file(ROOT+"/web/legacy_api.jsp");
	string header = Stdio.read_file(ROOT+"/web/includes/header.inc");
	string registration = Stdio.read_file(ROOT+"/web/login_reg.jsp");
	string partner = Stdio.read_file(ROOT+"/web/pg.jsp");
	string renderer = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/html_renderer.pike");
	string api = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	array(string) pages = ({"main.jsp","main_dark.jsp","main_ft.jsp",
		"main_ft_dark.jsp","game.jsp","entrycheck.jsp",
		"entrycheck_dark.jsp"});
	int valid = proxy && header && registration && partner && renderer && api &&
		search(header,"jakarta.servlet.http.HttpServletRequest")!=-1 &&
		search(header,"javax.servlet.http.HttpServletRequest")==-1 &&
		search(registration,"if( user==null || pswd==null)")!=-1 &&
		search(registration,"if( user==null || pswd==null)")<
			search(registration,"URLEncoder.encode(user") &&
		search(proxy,"http://127.0.0.1:8888/api/html?")!=-1 &&
		search(proxy,"query.length()>65536")!=-1 &&
		search(proxy,"html.replace(\"/api/html\",compatibilityPath)")!=-1 &&
		search(header,"buildLegacyApiCommand")!=-1 &&
		search(header,"legacyCommandValue")!=-1 &&
		search(registration,"http://127.0.0.1:8888/api/html?cmd=")!=-1 &&
		search(partner,"./legacy_api.jsp?userid=")!=-1 &&
		search(renderer,"string authenticated_txd")!=-1 &&
		search(renderer,"generate_txd(userid);")==-1 &&
		search(api,"authenticated_txd = txd;")!=-1 &&
		search(api,"authenticated_txd = generate_txd(auth_userid,stored_password)")!=-1 &&
		search(api,"auth[\"password\"]!=stored_password")!=-1 &&
		search(api,"search(request_id,userid+\"_\")!=0")!=-1;
	foreach(pages,string page){
		string source = Stdio.read_file(ROOT+"/web/"+page);
		if(!source || search(source,"legacy_api.jsp")==-1)
			valid = 0;
	}
	if(valid)
		test_pass();
	else
		test_fail("旧入口可能继续依赖单进程13800、丢失表单参数或改变txd书签");
}

void test_legacy_html_authenticated_txd_runtime()
{
	test_start("旧HTML动作链接保持完整认证TXD且不产生dummy密码");
	object api = HTTP_APID;
	string userid = "xd01legacytest";
	string password = "SafePass123";
	string txd = api->generate_txd(userid,password);
	string html = api->response_to_html("[查看:look]",userid,"look",txd);
	mapping decoded = api->decode_txd(txd);
	if(decoded && decoded["userid"]==userid &&
	   decoded["password"]==password &&
	   search(html,"txd="+txd)!=-1 &&
	   search(html,"~dummy")==-1)
		test_pass();
	else
		test_fail("旧HTML动作链接丢失认证密码、改变TXD或仍生成dummy");
}

void test_worker_failure_legacy_fallback_contract()
{
	test_start("worker故障全局熔断并持久回退旧主进程");
	string startup = Stdio.read_file(ROOT+"/docker/start-unified.sh");
	string cluster = Stdio.read_file(ROOT+"/scripts/map_worker_cluster.sh");
	int latch_position = -1;
	int stop_position = -1;
	int legacy_position = -1;
	if(startup){
		latch_position = search(startup,
			"latch_active_fallback \"worker-health-failure\"");
		stop_position = search(startup,
			"if ! stop_cluster_safely \"$traffic_mode\"; then",
			latch_position);
		legacy_position = search(startup,"start_legacy_main",stop_position);
	}
	if(startup && cluster && latch_position!=-1 && stop_position!=-1 &&
	   legacy_position!=-1 && latch_position<stop_position &&
	   stop_position<legacy_position &&
	   search(startup,"FALLBACK_LATCH=")!=-1 &&
	   search(startup,"persistent worker fallback latch found")!=-1 &&
	   search(startup,"health_failures >= 3")!=-1 &&
	   search(startup,"XIAND_MAP_WORKER_FAILOVER_SHUTDOWN")!=-1 &&
	   search(cluster,"gateway_failover_quiesce")!=-1 &&
	   search(cluster,"failover shutdown confirmed absent workers")!=-1 &&
	   search(startup,"if probe_output=\"$(XIAND_MAP_WORKER_CONFIG=")!=-1 &&
	   search(startup,"map-worker-monitor.log")!=-1 &&
	   search(startup,
		   "worker cluster could not prove safe shutdown")!=-1 &&
	   search(startup,
		   "legacy main ports are still occupied after worker shutdown")!=-1 &&
	   search(startup,"printf 'shutdown_safe\\r\\n'")!=-1 &&
	   search(cluster,"cluster_health()")!=-1 &&
	   search(cluster,"coordinator reports an unhealthy worker")!=-1 &&
	   search(cluster,"runtime_process_running \"$worker_id\"")!=-1)
		test_pass();
	else
		test_fail("active故障可能双写、自动反复切换或未在原端口恢复旧主进程");
}

void test_room_catalog_deploy_contract()
{
	test_start("部署原子增量同步持久化房间等级目录");
	string source = Stdio.read_file(ROOT+"/restart-docker.sh");
	if(source &&
	   search(source,"sync_room_level_catalog()")!=-1 &&
	   search(source,"$PROJECT_ROOT/data_xiand/room_level.log")!=-1 &&
	   search(source,"$data_dir/room_level.log")!=-1 &&
	   search(source,"grep -Fq \"|${room_path}|\"")!=-1 &&
	   search(source,"mktemp \"$target_dir/.room_level.merge.XXXXXX\"")!=-1 &&
	   search(source,"mv -f \"$temp_catalog\" \"$target_catalog\"")!=-1)
		test_pass();
	else
		test_fail("新地图目录未增量同步、会覆盖线上值或更新不具原子性");
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
	test_real_healthcheck_and_runtime_contracts();
	test_room_catalog_deploy_contract();
	test_worker_docker_start_chain_contract();
	test_local_worker_restart_chain_contract();
	test_testunit_and_include_isolation_contract();
	test_legacy_jsp_worker_gateway_contract();
	test_legacy_html_authenticated_txd_runtime();
	test_worker_failure_legacy_fallback_contract();
	print_summary();
	if(test_results["failed"]==0)
		return 0;
	return 1;
}
