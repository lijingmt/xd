#!/usr/bin/env pike
/**
 * 管理员修改玩家等级：权限、在线/离线、属性重算与立即存档。
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
	werror("\n[管理员改等级 %d] %s\n",test_results["total"],name);
	if(passed){
		test_results["passed"]++;
		werror("  ✓ 通过\n");
	}
	else{
		test_results["failed"]++;
		werror("  ✗ 失败: %s\n",reason);
	}
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

int main()
{
	string userid = "xd99leveltest99";
	string filepath = DATA_ROOT+"u/99/"+userid+".o";
	object|zero admin = 0;
	object|zero ordinary = 0;
	object|zero target = 0;
	object|zero command_ob = 0;
	object|zero verifier = 0;
	mapping denied = ([]);
	mapping online_result = ([]);
	mapping offline_result = ([]);
	string saved = "";
	string error_desc = "";
	int valid = 0;

	werror("\n========== 管理员修改等级测试 ==========\n");
	cleanup_player_files(userid);
	mixed err = catch{
		admin = TestOperator("xd99jinghaha");
		ordinary = TestOperator("xd99ordinary99");

		target = clone(GAMELIB_USER);
		target->set_name(userid);
		target->set_project("gamelib");
		target->setup("testunit-only");
		target->set_raceId("third");
		target->set_profeId("fangshi");
		target->setup_player("third","fangshi");
		target->level = 14;
		target->current_exp = 1234;
		target->set_att_by_level();
		target->save_with_result();

		command_ob = (object)(ROOT+
			"/gamelib/cmds/mgr_set_level.pike");
		denied = command_ob->change_user_level(
			ordinary,userid,18);
		test_result("普通玩家不能修改等级",
			!denied["ok"] && target->query_level()==14,
			"越权请求改动了玩家等级");

		online_result = command_ob->change_user_level(
			admin,userid,17);
		saved = Stdio.read_file(filepath);
		if(!saved)
			saved = "";
		verifier = clone(GAMELIB_USER);
		verifier->set_name(userid);
		verifier->set_project("gamelib");
		int online_restore_ok = verifier->restore();
		valid = online_result["ok"] && online_result["online"] &&
			target->query_level()==17 && target->current_exp==0 &&
			target->query_str()==34 && target->query_think()==44 &&
			online_restore_ok && verifier->query_level()==17 &&
			verifier->current_exp==0;
		test_result("在线方士改等级后重算属性并立即存档",
			valid,"在线改级、属性或存档不一致: ok="+
			online_result["ok"]+" online="+online_result["online"]+
			" level="+target->query_level()+
			" current_exp="+target->current_exp+
			" str="+target->query_str()+
			" think="+target->query_think()+
			" restore="+online_restore_ok+
			" disk_level="+verifier->query_level()+
			" disk_exp="+verifier->current_exp);
		destruct(verifier);
		verifier = 0;

		target->remove();
		target = 0;
		offline_result = command_ob->change_user_level(
			admin,userid,22);
		saved = Stdio.read_file(filepath);
		if(!saved)
			saved = "";
		verifier = clone(GAMELIB_USER);
		verifier->set_name(userid);
		verifier->set_project("gamelib");
		int offline_restore_ok = verifier->restore();
		test_result("离线账号修改后回写物理档案",
			offline_result["ok"] && !offline_result["online"] &&
			offline_restore_ok && verifier->query_level()==22 &&
			verifier->current_exp==0,
			"离线改级未正确落盘: ok="+
			offline_result["ok"]+" online="+
			offline_result["online"]+" file_size="+sizeof(saved)+
			" restore="+offline_restore_ok+
			" disk_level="+verifier->query_level()+
			" disk_exp="+verifier->current_exp);
		destruct(verifier);
		verifier = 0;

		test_result("等级上下限均受保护",
			!command_ob->change_user_level(admin,userid,0)["ok"] &&
			!command_ob->change_user_level(
				admin,userid,MAX_LEVEL+1)["ok"],
			"越界等级被接受");
	};
	if(err)
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
	if(err)
		test_result("运行时无异常",0,error_desc);

	if(target)
		target->remove();
	if(verifier)
		destruct(verifier);
	cleanup_player_files(userid);
	werror("管理员修改等级：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
