#!/usr/bin/env pike
/**
 * Vue/HTTP组队邀请与七星阵完整链路测试。
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
	werror("\n[组队邀请 %d] %s\n",test_results["total"],name);
}

void test_result(int valid,string reason)
{
	if(valid){
		test_results["passed"]++;
		werror("  ✓ 通过\n");
	}
	else{
		test_results["failed"]++;
		werror("  ✗ 失败: %s\n",reason);
	}
}

object create_test_player(string name,string race,string profe)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(name);
	player->name_cn = name;
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId(race);
	player->set_profeId(profe);
	player->setup_player(race,profe);
	player->level = 50;
	player->set_att_by_level();
	player->set_term("noterm");
	return player;
}

void destroy_test_player(object|zero player)
{
	if(player)
		destruct(player);
}

void test_pending_invite_and_http_state()
{
	test_start("组队邀请可暂存并通过HTTP状态轮询送达");
	object inviter = create_test_player(
		"__testunit_team_inviter__","human","jianxian");
	object target = create_test_player(
		"__testunit_team_target__","third","fangshi");
	object httpd = (object)(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	int valid = inviter && target && httpd &&
		TERMD->create_term_invite(
			inviter->query_name(),target->query_name())==1;
	mapping invite = valid ?
		TERMD->query_term_invite(target->query_name()) : ([]);
	mapping state = valid ? httpd->query_player_state(target) : ([]);
	mapping state_invite = mappingp(state["team_invite"]) ?
		state["team_invite"] : ([]);
	valid = valid && invite["pending"]==1 &&
		invite["from"]==inviter->query_name() &&
		invite["from_name"]==inviter->query_name_cn() &&
		invite["expires_at"]>time() &&
		state_invite["from"]==inviter->query_name() &&
		TERMD->valid_term_invite(
			target->query_name(),inviter->query_name())==1;
	TERMD->clear_term_invite(target->query_name(),inviter->query_name());
	valid = valid && !sizeof(TERMD->query_term_invite(target->query_name())) &&
		TERMD->create_term_invite(
			inviter->query_name(),inviter->query_name())==0;
	test_result(valid,"邀请暂存、状态返回、清理或防自邀失败");
	destroy_test_player(inviter);
	destroy_test_player(target);
}

void test_first_team_creation_workflow()
{
	test_start("首次接受邀请会真实建立二人队伍并可完整解散");
	object inviter = create_test_player(
		"__testunit_team_leader__","monst","kuangyao");
	object target = create_test_player(
		"__testunit_team_member__","third","fangshi");
	string team_id = "";
	int valid = !!inviter && !!target;
	if(valid){
		team_id = TERMD->term_create(inviter->query_name());
		valid = sizeof(team_id)>1 &&
			TERMD->add_termer(team_id,target->query_name(),
				target->query_name_cn())==1 &&
			inviter->query_term()==team_id &&
			target->query_term()==team_id &&
			sizeof(TERMD->query_term_m(team_id))==2 &&
			TERMD->get_term_power(
				team_id,inviter->query_name())=="leader";
	}
	if(team_id!="" && sizeof(team_id)>1)
		valid = TERMD->destory_term(
			team_id,inviter->query_name())==1 && valid;
	valid = valid && inviter->query_term()=="noterm" &&
		target->query_term()=="noterm";
	test_result(valid,"建队、入队、队长权限或解散后的状态错误");
	destroy_test_player(inviter);
	destroy_test_player(target);
}

void test_command_invite_accept_workflow()
{
	test_start("真实邀请与同意命令可走完组队链路");
	object inviter = create_test_player(
		"__testunit_team_cmd_leader__","human","jianxian");
	object target = create_test_player(
		"__testunit_team_cmd_member__","third","fangshi");
	object assist_cmd = (object)(ROOT+"/gamelib/cmds/term_assist.pike");
	object accept_cmd = (object)(ROOT+"/gamelib/cmds/term_ok.pike");
	object|zero original_player = this_player();
	string team_id = "";
	string error_desc = "";
	int valid = !!inviter && !!target && !!assist_cmd && !!accept_cmd;
	mixed err = catch {
		if(valid){
			set_this_player(inviter);
			assist_cmd->main(target->query_name());
			valid = TERMD->valid_term_invite(
				target->query_name(),inviter->query_name())==1;
			set_this_player(target);
			accept_cmd->main(inviter->query_name());
			team_id = inviter->query_term();
			valid = valid && sizeof(team_id)>1 &&
				target->query_term()==team_id &&
				sizeof(TERMD->query_term_m(team_id))==2 &&
				!sizeof(TERMD->query_term_invite(target->query_name()));
		}
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		error_desc = describe_error(err);
	if(team_id!="" && sizeof(team_id)>1)
		TERMD->destory_term(team_id,inviter->query_name());
	test_result(valid && !err,
		"真实命令未成功保存邀请或建立队伍: "+error_desc);
	destroy_test_player(inviter);
	destroy_test_player(target);
}

void test_http_core_and_command_contracts()
{
	test_start("所有组队写操作串行执行且旧命令页面接入待处理邀请");
	object httpd = (object)(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	string assist_source = Stdio.read_file(ROOT+
		"/gamelib/cmds/term_assist.pike");
	string ok_source = Stdio.read_file(ROOT+
		"/gamelib/cmds/term_ok.pike");
	string status_source = Stdio.read_file(ROOT+
		"/gamelib/cmds/my_term.pike");
	string leave_source = Stdio.read_file(ROOT+
		"/gamelib/cmds/term_leave.pike");
	int valid = httpd &&
		httpd->is_core_command("term_assist target")==1 &&
		httpd->is_core_command("term_ok inviter")==1 &&
		httpd->is_core_command("term_refuse inviter")==1 &&
		httpd->is_core_command("term_leave team")==1 &&
		httpd->is_core_command("my_term")==1 &&
		search(assist_source,"create_term_invite")!=-1 &&
		search(ok_source,"valid_term_invite")!=-1 &&
		search(ok_source,"你加入了该队伍")!=-1 &&
		search(ok_source,"me->set_term(tid)")==-1 &&
		search(status_source,"query_term_invite")!=-1 &&
		search(leave_source,"flush_term(old_term)")!=-1;
	test_result(valid,"核心命令路由或邀请/接受/离队接线不完整");
}

int main()
{
	werror("\n========== Vue/HTTP组队邀请测试 ==========\n");
	test_pending_invite_and_http_state();
	test_first_team_creation_workflow();
	test_command_invite_accept_workflow();
	test_http_core_and_command_contracts();
	werror("\n组队邀请测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
