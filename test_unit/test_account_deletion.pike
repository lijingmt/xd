#!/usr/bin/env pike
/** 整账号删除（Apple应用内删除账号）回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	test_results["total"]++;
	if(valid){
		test_results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		test_results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

string player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

string account_file(string account_id)
{
	return DATA_ROOT+"accounts/"+account_id[
		sizeof(account_id)-2..]+"/"+account_id+".json";
}

void cleanup_player(string userid)
{
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

int main()
{
	string account_id = "xd99testunitaccdel";
	string password = "testunit88";
	string child_id = "";
	string receipt = String.string2hex(Crypto.Random.random_string(32));
	object|zero root = 0;
	werror("\n========== 整账号删除测试 ==========\n");
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	mixed err = catch{
		root = clone(GAMELIB_USER);
		root->set_name(account_id);
		root->set_password(password);
		root->set_project("gamelib");
		root->set_userip("testunit-account-delete");
		root->set_account_owner(account_id);
		root->name_cn = "整号删除测试";
		root->set_raceId("human");
		root->set_profeId("jianxian");
		root->setup_player("human","jianxian");
		root->save_with_result();
		destruct(root);
		root = 0;

		mapping created = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi");
		if(mappingp(created["character"]))
			child_id = (string)created["character"]["id"];
		object child = clone(GAMELIB_USER);
		child->set_name(child_id);
		child->set_project("gamelib");
		int child_restored = child_id!="" ? child->restore() : 0;
		if(child_restored){
			child->name_cn = "整号删除子人物";
			child->set_raceId("third");
			child->set_profeId("fangshi");
			child->setup_player("third","fangshi");
			child->save_with_result();
		}
		destruct(child);
		check("建立默认人物与子人物",
			(int)created["ok"] && child_restored &&
			Stdio.file_size(player_file(child_id))>0 &&
			Stdio.file_size(account_file(account_id))>0,
			sprintf("created=%O child_id=%O",created,child_id));

		mapping deleted = ACCOUNT_CHARACTERD->retire_entire_account(
			account_id,receipt);
		check("整号删除成功并返回归档数",
			(int)deleted["ok"] && (int)deleted["archived"]==2,
			sprintf("deleted=%O",deleted));
		check("人物物理存档已归档移除",
			Stdio.file_size(player_file(account_id))<=0 &&
			Stdio.file_size(player_file(child_id))<=0,
			sprintf("root.o=%d child.o=%d",
				Stdio.file_size(player_file(account_id)),
				Stdio.file_size(player_file(child_id))));
		check("账号索引记录已删除",
			Stdio.file_size(account_file(account_id))<=0,
			"account json still present");
		mapping second = ACCOUNT_CHARACTERD->retire_entire_account(
			account_id,receipt);
		/* 幂等：重复调用要么失败关闭，要么成功且不再归档任何人物；
		 * 两种结果都不能复活档案。 */
		check("重复删除幂等且不复活任何档案",
			((int)second["ok"] && (int)second["archived"]==0) ||
			!(int)second["ok"],
			sprintf("second=%O",second));
	};
	if(err){
		werror("整号删除测试运行异常: %s\n",describe_error(err));
		test_results["failed"]++;
	}
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	if(child_id!="")
		cleanup_player(child_id);
	werror("========== 整号删除测试结束 ==========\n");
	werror("通过 %d / %d\n",test_results["passed"],
		test_results["total"]);
	return test_results["failed"]>0;
}
