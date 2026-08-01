#!/usr/bin/env pike
/**
 * 意见反馈闭环：输入保护、权限、采纳发奖、离线凭据与幂等性。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total":0,
	"passed":0,
	"failed":0,
]);

class TestOperator
{
	string operator_name;
	protected void create(string name)
	{
		operator_name = name;
	}
	string query_name()
	{
		return operator_name;
	}
	object load_player(string userid)
	{
		object player = clone(GAMELIB_USER);
		player->set_name(userid);
		player->set_project("gamelib");
		if(player->restore())
			return player;
		destruct(player);
		return 0;
	}
}

void test_result(string name,int passed,string reason)
{
	test_results["total"]++;
	werror("\n[意见反馈 %d] %s\n",test_results["total"],name);
	if(passed){
		test_results["passed"]++;
		werror("  ✓ 通过\n");
	}
	else{
		test_results["failed"]++;
		werror("  ✗ 失败: %s\n",reason);
	}
}

object create_feedback_player(string userid,string name_cn)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->name_cn = name_cn;
	player->set_project("gamelib");
	player->setup("testunit-only");
	player->set_raceId("third");
	player->set_profeId("fangshi");
	player->setup_player("third","fangshi");
	player->save_with_result();
	return player;
}

void cleanup_player_files(string userid)
{
	string filepath = DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+
		"/"+userid+".o";
	rm(filepath);
	rm(filepath+".tmp");
	rm(filepath+".bak");
	rm(filepath+".bak.tmp");
}

void cleanup_feedbacks(object player)
{
	array(mapping(string:mixed)) records =
		FEEDBACKD->query_player_feedback(player,20);
	foreach(records,mapping(string:mixed) one)
		FEEDBACKD->remove_test_feedback((int)one["id"]);
}

int main()
{
	string adopt_user = "__testunit_feedback_adopt__";
	string reject_user = "__testunit_feedback_reject__";
	string offline_user = "__testunit_feedback_offline__";
	object|zero adopt_player = 0;
	object|zero reject_player = 0;
	object|zero offline_player = 0;
	object|zero offline_verifier = 0;
	object admin = TestOperator("xd99jinghaha");
	object ordinary = TestOperator("xd99ordinary99");
	object command_ob;
	mapping(string:mixed) submitted = ([]);
	mapping(string:mixed) rejected_submit = ([]);
	mapping(string:mixed) review = ([]);
	mapping(string:mixed) second_review = ([]);
	string error_desc = "";

	werror("\n========== 意见反馈系统测试 ==========\n");
	cleanup_player_files(adopt_user);
	cleanup_player_files(reject_user);
	cleanup_player_files(offline_user);
	mixed err = catch{
		adopt_player = create_feedback_player(adopt_user,"采纳反馈测试者");
		reject_player = create_feedback_player(reject_user,"未采纳反馈测试者");
		cleanup_feedbacks(adopt_player);
		cleanup_feedbacks(reject_player);

		mapping short_result = FEEDBACKD->submit_feedback(adopt_player,"短");
		test_result("过短内容被拒绝",
			!short_result["ok"],"无效短文本被写入");

		submitted = FEEDBACKD->submit_feedback(adopt_player,
			"建议[伪按钮:shutdown]优化九霄路线提示");
		mapping detail = FEEDBACKD->query_admin_feedback_detail(
			admin,(int)submitted["id"]);
		test_result("玩家意见持久化且控制符被净化",
			submitted["ok"] && sizeof(detail) &&
			search((string)detail["content"],"[伪按钮") == -1 &&
			Stdio.file_size(DATA_ROOT+"feedback/feedbacks.o")>0,
			"提交、净化或物理存档失败");

		mapping denied = FEEDBACKD->review_feedback(
			ordinary,(int)submitted["id"],"adopt");
		test_result("普通玩家不能审核反馈",
			!denied["ok"] &&
			FEEDBACKD->query_admin_feedback_count(ordinary,"all")==0,
			"非管理员越权读取或审核");

		command_ob = (object)(ROOT+"/gamelib/cmds/mgr_feedback.pike");
		review = command_ob->adopt_and_reward(
			admin,(int)submitted["id"]);
		detail = FEEDBACKD->query_admin_feedback_detail(
			admin,(int)submitted["id"]);
		test_result("管理员采纳后发放100碎玉并立即存档",
			review["ok"] && review["delivered"]==1 &&
			YUSHID->query_all_num(adopt_player)==100 &&
			detail["status"]=="adopted" &&
			detail["reward_status"]=="delivered" &&
			(mappingp(adopt_player["/feedback/reward_claimed"])),
			"采纳状态、玉石或领取凭据不一致");

		second_review = command_ob->adopt_and_reward(
			admin,(int)submitted["id"]);
		test_result("重复确认和重复补发保持幂等",
			second_review["ok"] &&
			YUSHID->query_all_num(adopt_player)==100,
			"重复审核产生了额外玉石");

		rejected_submit = FEEDBACKD->submit_feedback(reject_player,
			"希望调整新手阶段的任务说明文字");
		mapping reject_result = FEEDBACKD->review_feedback(
			admin,(int)rejected_submit["id"],"reject");
		mapping reject_detail = FEEDBACKD->query_admin_feedback_detail(
			admin,(int)rejected_submit["id"]);
		test_result("未采纳反馈不发奖励",
			rejected_submit["ok"] && reject_result["ok"] &&
			reject_detail["status"]=="rejected" &&
			YUSHID->query_all_num(reject_player)==0,
			"未采纳状态错误或发生发奖");

		offline_player = create_feedback_player(offline_user,
			"离线反馈测试者");
		cleanup_feedbacks(offline_player);
		mapping offline_submit = FEEDBACKD->submit_feedback(
			offline_player,"离线时也应安全收到采纳意见的玉石奖励");
		destruct(offline_player);
		offline_player = 0;
		mapping offline_review = command_ob->adopt_and_reward(
			admin,(int)offline_submit["id"]);
		offline_verifier = admin->load_player(offline_user);
		test_result("离线玩家采纳奖励写入物理档案",
			offline_submit["ok"] && offline_review["ok"] &&
			offline_review["delivered"]==1 && offline_verifier &&
			YUSHID->query_all_num(offline_verifier)==100 &&
			mappingp(offline_verifier["/feedback/reward_claimed"]),
			"离线加载、发奖或重新读取档案失败");

		string vue_source = Stdio.read_file(ROOT+"/vue_source/index.html");
		string game_deal_source = Stdio.read_file(
			ROOT+"/gamelib/cmds/game_deal.pike");
		string game_detail_source = Stdio.read_file(
			ROOT+"/gamelib/cmds/game_detail.pike");
		string user_source = Stdio.read_file(
			ROOT+"/gamelib/clone/user.pike");
		string thread_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/thread_manager.pike");
		program feedback_command =
			(program)(ROOT+"/gamelib/cmds/feedback.pike");
		test_result("反馈仅位于设置且后台与核心命令路由齐全",
			feedback_command && vue_source &&
			search(vue_source,"sendQuickCommand('feedback')")==-1 &&
			game_detail_source &&
			search(game_detail_source,"[意见反馈:feedback]")!=-1 &&
			user_source &&
			search(user_source,"|[反馈:feedback]")==-1 &&
			game_deal_source && search(game_deal_source,"mgr_feedback")!=-1 &&
			thread_source && search(thread_source,"\"feedback\"")!=-1 &&
			search(thread_source,"\"mgr_feedback\"")!=-1,
			"设置入口、顶层入口清理、后台或HTTP串行路由遗漏");
	};
	if(err){
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
		test_result("运行时无异常",0,error_desc);
	}

	if(adopt_player){
		cleanup_feedbacks(adopt_player);
		foreach(all_inventory(adopt_player),object item)
			item->remove();
		destruct(adopt_player);
	}
	if(reject_player){
		cleanup_feedbacks(reject_player);
		foreach(all_inventory(reject_player),object item)
			item->remove();
		destruct(reject_player);
	}
	if(offline_player){
		cleanup_feedbacks(offline_player);
		foreach(all_inventory(offline_player),object item)
			item->remove();
		destruct(offline_player);
	}
	if(offline_verifier){
		cleanup_feedbacks(offline_verifier);
		foreach(all_inventory(offline_verifier),object item)
			item->remove();
		destruct(offline_verifier);
	}
	cleanup_player_files(adopt_user);
	cleanup_player_files(reject_user);
	cleanup_player_files(offline_user);
	werror("意见反馈：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
