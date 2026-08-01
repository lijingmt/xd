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

int main()
{
	werror("\n========== Xiand安全加固测试 ==========\n");
	test_login_secret_redaction();
	test_log_rotation_and_registry_cleanup();
	test_purchase_path_guards();
	test_http_request_guards();
	test_database_error_redaction();
	werror("\n安全加固：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
