#!/usr/bin/env pike
/** 登录敏感信息、商品路径和长期守护映射的安全回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	werror("\n[安全加固 %d] %s\n",results["total"],name);
	if(valid){
		results["passed"]++;
		werror("  ✓ 通过\n");
	}
	else{
		results["failed"]++;
		werror("  ✗ 失败: %s\n",reason);
	}
}

void test_login_secret_redaction()
{
	string source = Stdio.read_file(ROOT+"/gamelib/d/init");
	int valid = source &&
		search(source,"werror(\"tieToMobile mobile=")==-1 &&
		search(source,"werror(\"tie_yes num=")==-1 &&
		search(source,"werror(\"check_mobile")==-1 &&
		search(source,"werror(\"======arg:")==-1 &&
		search(source,"[设置密码:"+"arg+")==-1 &&
		search(source,"[设置密码成功]")!=-1;
	check("手机号与新旧密码不会写入运行日志",valid,
		"登录入口仍存在敏感参数日志");
}

void test_log_rotation_and_registry_cleanup()
{
	string restart = Stdio.read_file(ROOT+
		"/scripts/restart_with_testunit.sh");
	string rate = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/rate_limit.pike");
	string conn = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/virtual_conn.pike");
	int valid = restart && search(restart,"ERROR_LOG=")!=-1 &&
		search(restart,"10485760")!=-1 &&
		rate && search(rate,"rate_limits[ip] = 0")==-1 &&
		search(rate,"m_delete(rate_limits,ip)")!=-1 &&
		conn && search(conn,"vconnections[userid] = 0")==-1 &&
		search(conn,"m_delete(vconnections,userid)")!=-1;
	check("错误日志有界轮转且过期注册表不留空键",valid,
		"日志或守护映射仍可能无界增长");
}

void test_purchase_path_guards()
{
	string source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/buyd.pike");
	int valid = source &&
		search(source,"tmp->item_type!=item_type")!=-1 &&
		search(source,"search(item_name,\"..\")!=-1")!=-1 &&
		search(source,"item_name[0]=='/'")!=-1 &&
		search(source,"商品文件暂时不可用")!=-1;
	check("商品类别、绝对路径、目录穿越和缺失对象均被拒绝",valid,
		"商品入口仍可伪造类型或路径");
}

void test_http_request_guards()
{
	string config = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/config.pike");
	string daemon = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string utils = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/utils.pike");
	int valid = config && daemon && utils &&
		search(config,"MAX_HTTP_BODY_SIZE = 65536")!=-1 &&
		search(daemon,"Request too large")!=-1 &&
		search(utils,"Invalid static path")!=-1 &&
		search(utils,"search(path,\"..\")!=-1")!=-1;
	check("HTTP请求体与静态文件路径均有硬边界",valid,
		"HTTP入口仍缺少正文或路径边界");
}

void test_database_error_redaction()
{
	string source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/auctiond.pike");
	int create_start = search(source,"protected void create()");
	int next_function = search(source,"private void time_task()",create_start);
	string create_source = "";
	if(create_start>=0 && next_function>create_start)
		create_source = source[create_start..next_function-1];
	int valid = source && create_source!="" &&
		search(create_source,"mixed db_err = catch")!=-1 &&
		search(create_source,"db=Sql.Sql(dbSql,optionsMap)")!=-1 &&
		search(create_source,"describe_error(db_err)")==-1 &&
		search(create_source,"database unavailable")!=-1;
	check("拍卖数据库初始化失败不泄露连接密码",valid,
		"SQL 初始化仍可能让含密码的异常回溯逃出");
}

void test_auction_sql_parameters()
{
	string source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/auctiond.pike");
	int valid = source &&
		search(source,"like :GOODS_PATTERN")!=-1 &&
		search(source,"db->query(querySql,queryParams)")!=-1 &&
		search(source,"where saler_id=:PLAYER_ID")!=-1 &&
		search(source,"where buyer_id=:PLAYER_ID")!=-1 &&
		search(source,"status_sql!=\"in (0,3)\"")!=-1;
	check("拍卖搜索、上架与领取身份均使用SQL参数绑定",valid,
		"拍卖数据库仍存在可拼接的玩家输入");
}

void test_auction_failure_is_non_destructive()
{
	string vendue = Stdio.read_file(ROOT+
		"/gamelib/cmds/vendue_confirm.pike");
	string auction = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/auctiond.pike");
	string dockerfile = Stdio.read_file(ROOT+"/docker/Dockerfile.all");
	string docker_startup = Stdio.read_file(ROOT+"/docker/start-unified.sh");
	string restart = Stdio.read_file(ROOT+"/restart-docker.sh");
	int add_start = auction ? search(auction,
		"int add_new_sale_info(") : -1;
	int add_end = auction ? search(auction,
		"array(mapping(string:mixed)) query_getback_as_saler",add_start) : -1;
	string add_source = "";
	if(add_start>=0 && add_end>add_start)
		add_source = auction[add_start..add_end-1];
	int sale_call = vendue ? search(vendue,
		"int sale_added = AUCTIOND->add_new_sale_info") : -1;
	int fee_charge = vendue ? search(vendue,
		"me->del_account(fee)",sale_call) : -1;
	int valid = vendue && auction && dockerfile && docker_startup && restart &&
		sale_call>=0 && fee_charge>sale_call &&
		search(vendue,"if(sale_added==1)")!=-1 &&
		search(vendue,"本次未扣手续费，物品也未移除")!=-1 &&
		add_source!="" &&
		search(add_source,"[add_new_sale_info] [database unavailable]")!=-1 &&
		search(add_source,"db=0;")!=-1 &&
		search(docker_startup,"MySQL authentication failed")!=-1 &&
		search(dockerfile,"-p${MYSQL_PASSWORD}")==-1 &&
		search(docker_startup,"-p${MYSQL_PASSWORD}")==-1 &&
		search(restart,"SELECT 1")!=-1 &&
		search(restart,"MySQL 认证失败")!=-1;
	check("拍卖失败不扣费且部署拒绝错误MySQL凭证",valid,
		"拍卖失败仍可能扣费或容器会带错误凭证启动");
}

void test_auction_commands_compile()
{
	array(string) files=get_dir(ROOT+"/gamelib/cmds")||({});
	array(string) invalid=({});
	int checked=0;
	foreach(files,string file){
		if(search(file,"vendue")!=0 || !has_suffix(file,".pike"))
			continue;
		checked++;
		mixed err=catch {
			compile_file(ROOT+"/gamelib/cmds/"+file);
		};
		if(err)
			invalid+=({file});
	}
	check("全部拍卖命令均能在运行时编译",
		checked>0 && !sizeof(invalid),
		"无法编译: "+(invalid*", "));
}

void test_legacy_login_entry_guards()
{
	array(string) files = ({
		"login.pike","login_check.pike","login_check5.pike",
		"login_check_intro.pike","login_entrycheck_p.pike",
		"login_fee.pike","login_fee_xd.pike","login_intro.pike",
		"login_monst.pike","login_regnew.pike","login_regnew_p.pike",
		"login_band.pike",
	});
	int valid = 1;
	foreach(files,string file){
		string source = Stdio.read_file(ROOT+"/lowlib/system/cmds/"+file);
		if(!source || search(source,"path!=\"gamelib\"")==-1)
			valid = 0;
	}
	string connd = Stdio.read_file(ROOT+"/lowlib/connd.pike");
	string conn = Stdio.read_file(ROOT+"/lowlib/conn.pike");
	string driver = Stdio.read_file(ROOT+"/lowlib/driver.pike");
	valid = valid && connd && conn && driver &&
		search(connd,"registration_attempt_allowed")!=-1 &&
		search(connd,"authentication_attempt_allowed")!=-1 &&
		search(connd,"MAX_REGISTRATION_RATE_KEYS")!=-1 &&
		search(connd,"if(ip==\"127.0.0.1\" || ip==\"::1\")") == -1 &&
		search(conn,"query_remote_ip")!=-1 &&
		search(Stdio.read_file(ROOT+
			"/lowlib/system/cmds/login_regnew.pike"),
			"safe_registration_log_field")!=-1 &&
		search(driver,"REDACTED sensitive error context")!=-1;
	array(string) admin_files = ({"login_desc2.pike","login_pv.pike",
		"login_regtotal.pike","login_tongji.pike"});
	foreach(admin_files,string file){
		string source = Stdio.read_file(ROOT+"/lowlib/system/cmds/"+file);
		if(!source || search(source,"XIAND_MAINTENANCE_TOKEN")==-1 ||
		   search(source,"path!=\"gamelib\"")==-1)
			valid = 0;
	}
	string login_check = Stdio.read_file(ROOT+
		"/lowlib/system/cmds/login_check.pike");
	valid = valid && login_check &&
		search(login_check,"authentication_rate_limit_allowed")!=-1;
	check("旧式登录只加载gamelib并按真实连接IP限制注册",valid,
		"旧式登录路径、注册限流或异常脱敏缺失");
}

void test_runtime_debug_logs_removed()
{
	array(string) files = ({
		"/lowlib/driver.pike",
		"/lowlib/system/master.pike",
		"/lowlib/system/cmds/login_check.pike",
		"/lowlib/system/inherit/feature/save.pike",
		"/gamelib/single/daemons/_http_api_mod/command_queue.pike",
		"/gamelib/single/daemons/_http_api_mod/html_renderer.pike",
		"/restart-docker.sh",
	});
	int valid = 1;
	foreach(files,string file){
		string source = Stdio.read_file(ROOT+file);
		if(!source || search(source,"xiand_login_debug.log")!=-1 ||
		   search(source,"xiand_conn_debug.log")!=-1)
			valid = 0;
	}
	string queue = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/command_queue.pike");
	string renderer = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/html_renderer.pike");
	string driver = Stdio.read_file(ROOT+"/lowlib/driver.pike");
	valid = valid && queue && renderer && driver &&
		search(queue,"Enqueued request for %s: cmd=%s")==-1 &&
		search(renderer,"response_to_html called! cmd=%s")==-1 &&
		search(driver,"debug_log->write(\"%s:%d: %s\\n\"")==-1;
	string taskd = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/taskd.pike");
	valid = valid && taskd && search(taskd,"taskdrop.log")==-1;
	check("登录连接与任务掉落成功路径不再高频写调试日志",valid,
		"仍存在无界高频调试日志");
}

void test_bossdrop_sentinels()
{
	string source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/bossdropd.pike") || "";
	object bossdropd = (object)(ROOT+
		"/gamelib/single/daemons/bossdropd.pike");
	int valid = source!="" &&
		search(source,"String.trim_all_whites")==-1 &&
		search(source,"String.trim_whites")!=-1 &&
		bossdropd &&
		bossdropd->get_bossdrop_specitem("choulounianshou")=="" &&
		bossdropd->get_bossdrop_specitem("xueduchongwang")=="" &&
		bossdropd->get_bossdrop_specitem("liubimojun")==
			"bossdrop/bawanghuiji";
	check("Boss掉落无弃用裁剪告警且正确区分and/end哨兵",valid,
		"CSV裁剪仍触发弃用告警，或哨兵被当成物品路径");
}

void test_health_and_deployment_secrets()
{
	string daemon = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string accounts = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/account_characters.pike");
	string dockerfile = Stdio.read_file(ROOT+"/docker/Dockerfile.all");
	string docker_startup = Stdio.read_file(ROOT+"/docker/start-unified.sh");
	string dockerignore = Stdio.read_file(ROOT+"/.dockerignore");
	string restart = Stdio.read_file(ROOT+"/restart-docker.sh");
	string auction = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/auctiond.pike");
	string ranking = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/paihangd.pike");
	object rankingd = (object)(ROOT+
		"/gamelib/single/daemons/paihangd.pike");
	array(mapping(string:mixed)) old_ranking = ({(["id":"old"])});
	array(mapping(string:mixed)) empty_ranking = ({});
	object httpd = (object)(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	int valid = daemon && accounts && dockerfile && docker_startup &&
		dockerignore && restart &&
		auction && ranking && rankingd &&
		httpd &&
		httpd->normalize_http_client_ip("127.0.0.1:54321")=="127.0.0.1" &&
		httpd->normalize_http_client_ip("[::1]:54321")=="::1" &&
		search(daemon,"configured_health_token")!=-1 &&
		search(daemon,"detailed_health")!=-1 &&
		search(daemon,"sizeof(configured_health_token)>=24")!=-1 &&
		search(daemon,"string normalize_http_client_ip")!=-1 &&
		search(daemon,"string client_ip = normalize_http_client_ip")!=-1 &&
		search(accounts,"normalize_http_client_ip")!=-1 &&
		search(docker_startup,"MYSQL_PASSWORD is required")!=-1 &&
		search(dockerignore,".env")!=-1 &&
		search(restart,"-e MYSQL_PASSWORD ")!=-1 &&
		search(restart,"-e MYSQL_PASSWORD=\"$MYSQL_PASSWORD\"")==-1 &&
		search(restart,"--log-opt max-size=50m")!=-1 &&
		search(auction,"getenv(\"MYSQL_PASSWORD\") || \"\"")!=-1 &&
		search(ranking,"getenv(\"MYSQL_PASSWORD\") || \"\"")!=-1 &&
		search(ranking,"private Thread.Mutex database_lock")!=-1 &&
		search(ranking,"for(int attempt=0;attempt<2;attempt++)")!=-1 &&
		search(ranking,"rows = db->query(query_sql)")!=-1 &&
		search(ranking,"db = 0;")!=-1 &&
		search(ranking,"if((int)refreshed[\"ok\"])")!=-1 &&
		search(ranking,
			"select distinct id,name_cn,home_bi from xd_daily_user")!=-1 &&
		rankingd->test_preserve_ranking_snapshot(
			0,old_ranking,empty_ranking)==old_ranking &&
		sizeof(rankingd->test_preserve_ranking_snapshot(
			1,old_ranking,empty_ranking))==0;
	check("详细健康指标受保护且数据库口令无源码默认值",valid,
		"健康指标或部署凭证仍有暴露面");
}

void test_log_policy_and_atomic_recovery()
{
	string policy = Stdio.read_file(ROOT+"/deploy/logrotate/xiand");
	string restart = Stdio.read_file(ROOT+"/restart-docker.sh");
	string installer = Stdio.read_file(ROOT+
		"/scripts/install-logrotate.sh");
	string save = Stdio.read_file(ROOT+
		"/lowlib/system/inherit/feature/save.pike");
	string users = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/user_countd.pike");
	int valid = policy && restart && installer && save && users &&
		search(policy,"maxsize 50M")!=-1 &&
		search(policy,"rotate 14")!=-1 &&
		search(restart,"ensure_logrotate_policy")!=-1 &&
		search(restart,
			"cmp -s \"$source_policy\" \"$target_policy\"")!=-1 &&
		search(restart,"sudo $installer")!=-1 &&
		search(installer,"logrotate -d")!=-1 &&
		search(save,"promote_recovered_save")!=-1 &&
		search(save,"restore backup promoted")!=-1 &&
		search(users,"me->password")==-1 &&
		search(users,"[REDACTED]")!=-1;
	check("日志有轮转策略且原子备份恢复后会自愈主档",valid,
		"日志增长、凭证审计或存档恢复自愈缺失");
}

int main()
{
	werror("\n========== Xiand安全加固测试 ==========\n");
	test_login_secret_redaction();
	test_log_rotation_and_registry_cleanup();
	test_purchase_path_guards();
	test_http_request_guards();
	test_database_error_redaction();
	test_auction_sql_parameters();
	test_auction_failure_is_non_destructive();
	test_auction_commands_compile();
	test_legacy_login_entry_guards();
	test_runtime_debug_logs_removed();
	test_bossdrop_sentinels();
	test_health_and_deployment_secrets();
	test_log_policy_and_atomic_recovery();
	werror("\n安全加固：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
