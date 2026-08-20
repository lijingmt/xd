#!/usr/bin/env pike
/** 多人账号安全删除（可恢复归档）回归。 */

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

string archive_dir(string account_id,string receipt)
{
	return DATA_ROOT+"deleted_characters/"+
		account_id[sizeof(account_id)-2..]+"/"+account_id+"/"+receipt;
}

void cleanup_player(string userid)
{
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_root(string account_id,string password)
{
	object player = clone(GAMELIB_USER);
	player->set_name(account_id);
	player->set_password(password);
	player->set_project("gamelib");
	player->set_userip("testunit-character-delete");
	player->set_account_owner(account_id);
	player->name_cn = "安全归档测试";
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->save_with_result();
	return player;
}

int main()
{
	string account_id = "xd99testunitchardelete";
	string password = "testunit88";
	string first_id = "";
	string second_id = "";
	string receipt = "d"*64;
	object|zero root = 0;
	object|zero online_child = 0;
	object original_player = this_player();
	werror("\n========== 账号人物安全归档测试 ==========\n");
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	mixed err = catch{
		root = create_root(account_id,password);
		destruct(root);
		root = 0;
		mapping first = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi");
		if(mappingp(first["character"]))
			first_id = (string)first["character"]["id"];
		object first_seed = clone(GAMELIB_USER);
		first_seed->set_name(first_id);
		first_seed->set_project("gamelib");
		int first_restored = first_id!="" ? first_seed->restore() : 0;
		if(first_restored){
			first_seed->name_cn = "归档方士";
			first_seed->set_raceId("third");
			first_seed->set_profeId("fangshi");
			first_seed->setup_player("third","fangshi");
			first_seed->save_with_result();
		}
		destruct(first_seed);
		mapping second = ACCOUNT_CHARACTERD->create_character(
			account_id,"monst","wuyao");
		if(mappingp(second["character"]))
			second_id = (string)second["character"]["id"];
		check("建立默认人物与两个可删除子人物",
			(int)first["ok"] && first_restored && (int)second["ok"] &&
			first_id!="" && second_id!="" &&
			Stdio.file_size(player_file(first_id))>0 &&
			Stdio.file_size(player_file(second_id))>0,
			sprintf("测试人物没有完整建立: first=%O second=%O",
				first,second));

		mapping root_rejected = ACCOUNT_CHARACTERD->
			retire_account_character(account_id,account_id,"a"*64);
		check("注册账号默认人物永远不能删除",
			!(int)root_rejected["ok"] &&
			search((string)root_rejected["message"],"默认人物")!=-1 &&
			Stdio.file_size(player_file(account_id))>0,
			sprintf("root result=%O",root_rejected));

		online_child = clone(GAMELIB_USER);
		online_child->set_name(first_id);
		online_child->set_project("gamelib");
		int restored = online_child->restore();
		object runtime_key = ACCOUNT_CHARACTERD->
			query_account_runtime_mutex(account_id)->lock();
		int registered = restored ? ACCOUNT_CHARACTERD->
			prepare_character_login_locked(online_child) : 0;
		destruct(runtime_key);
		mapping online_rejected = ACCOUNT_CHARACTERD->
			retire_account_character(account_id,first_id,receipt);
		check("在线人物失败关闭，不移动物理存档",
			restored && registered && !(int)online_rejected["ok"] &&
			search((string)online_rejected["message"],"仍然在线")!=-1 &&
			Stdio.file_size(player_file(first_id))>0,
			sprintf("restored=%d registered=%d result=%O",
				restored,registered,online_rejected));
		destruct(online_child);
		online_child = 0;
		ACCOUNT_CHARACTERD->query_active_characters(account_id);

		mapping bookmark = ACCOUNT_CHARACTERD->create_character_bookmark(
			account_id,first_id,password);
		string bookmark_token = (string)(bookmark["bookmark_token"] || "");
		mapping retired = ACCOUNT_CHARACTERD->retire_account_character(
			account_id,first_id,receipt);
		mapping after = ACCOUNT_CHARACTERD->query_account_characters(account_id);
		mapping revoked_bookmark = ACCOUNT_CHARACTERD->
			verify_character_bookmark(account_id,first_id,
				bookmark_token,password);
		mapping manifest = ([]);
		mixed manifest_error = catch {
			manifest = Standards.JSON.decode(Stdio.read_file(
				archive_dir(account_id,receipt)+"/manifest.json"));
		};
		check("离线子人物移入受限归档而非直接销毁",
			(int)retired["ok"] && !(int)retired["already"] &&
			(int)retired["refund_suiyu"]==0 &&
			Stdio.file_size(player_file(first_id))<0 &&
			Stdio.file_size(archive_dir(account_id,receipt)+"/profile.o")>0 &&
			!manifest_error && (string)manifest["state"]=="archived" &&
			(string)manifest["character_id"]==first_id,
			sprintf("retired=%O manifest=%O error=%O",
				retired,manifest,manifest_error));
		check("归档后索引紧缩栏位、撤销书签并保留其他人物",
			(int)after["ok"] && sizeof((array)after["characters"])==2 &&
			(string)after["characters"][0]["id"]==account_id &&
			(string)after["characters"][1]["id"]==second_id &&
			(int)after["characters"][1]["slot"]==2 &&
			!ACCOUNT_CHARACTERD->account_owns_character(account_id,first_id) &&
			!(int)revoked_bookmark["ok"],
			sprintf("after=%O bookmark=%O",after,bookmark));

		mapping retried = ACCOUNT_CHARACTERD->retire_account_character(
			account_id,first_id,receipt);
		mapping forged_retry = ACCOUNT_CHARACTERD->
			retire_account_character(account_id,first_id,"e"*64);
		check("同一回执重试幂等，不同回执不能伪造成功",
			(int)retried["ok"] && (int)retried["already"] &&
			!(int)forged_retry["ok"],
			sprintf("retry=%O forged=%O",retried,forged_retry));

		string interrupted_receipt = "f"*64;
		string interrupted_dir = archive_dir(account_id,
			interrupted_receipt);
		Stdio.mkdirhier(interrupted_dir);
		mapping interrupted_manifest = ([
			"version":1,"state":"pending","account_id":account_id,
			"character_id":second_id,
			"receipt_hash":interrupted_receipt,
			"requested_at":time(),"original_slot":2,
		]);
		Stdio.write_file(interrupted_dir+"/manifest.json",
			Standards.JSON.encode(interrupted_manifest));
		int interrupted_move = mv(player_file(second_id),
			interrupted_dir+"/profile.o");
		mapping resumed = ACCOUNT_CHARACTERD->retire_account_character(
			account_id,second_id,interrupted_receipt);
		mapping resumed_after = ACCOUNT_CHARACTERD->
			query_account_characters(account_id);
		mapping resumed_manifest = Standards.JSON.decode(
			Stdio.read_file(interrupted_dir+"/manifest.json"));
		check("主档已移动但索引未提交的崩溃窗可用同一回执续做",
			interrupted_move && (int)resumed["ok"] &&
			sizeof((array)resumed_after["characters"])==1 &&
			(string)resumed_after["characters"][0]["id"]==account_id &&
			(string)resumed_manifest["state"]=="archived" &&
			(int)resumed_manifest["resumed_after_interruption"]==1,
			sprintf("move=%d resumed=%O after=%O manifest=%O",
				interrupted_move,resumed,resumed_after,resumed_manifest));

		string api_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/account_characters.pike") || "";
		string gateway_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/pike_gateway.pike") || "";
		check("HTTP删除必须重验密码、精确ID且跨Worker证明离线",
			search(api_source,"confirm_character_id")!=-1 &&
			search(api_source,"account_password!=stored_password")!=-1 &&
			search(gateway_source,"pike_gateway_character_delete_guard")!=-1 &&
			search(gateway_source,"query_pike_gateway_online_users()")!=-1 &&
			search(gateway_source,"跨Worker在线状态暂不可验证")!=-1,
			"删除接口安全门禁不完整");
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("账号人物安全归档测试无运行异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(online_child)
		destruct(online_child);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	if(first_id!="") cleanup_player(first_id);
	if(second_id!="") cleanup_player(second_id);
	cleanup_player(account_id);
	werror("账号人物安全归档：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
