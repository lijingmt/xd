#!/usr/bin/env pike
/** 注册账号多人物、旧档零迁移与接口边界回归。 */

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

string account_file(string userid)
{
	return DATA_ROOT+"accounts/"+userid[sizeof(userid)-2..]+
		"/"+userid+".json";
}

void cleanup_player(string userid)
{
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
	rm(path+".password.tmp");
	rm(path+".password.bak.tmp");
	rm(path+".password.restore.tmp");
	rm(path+".password.backup.tmp");
}

object create_legacy_player(string userid,string password)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->set_password(password);
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn = "旧档剑客";
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->save();
	return player;
}

int main()
{
	string account_id = "xd99testunitmultichar";
	string password = "testunit88";
	string character_id = "";
	object|zero legacy = 0;
	object|zero restored = 0;
	werror("\n========== 注册账号多人物测试 ==========\n");
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	mixed err = catch{
		legacy = create_legacy_player(account_id,password);
		mapping before = ACCOUNT_CHARACTERD->
			query_account_characters(account_id);
		check("旧账号无索引时按原人物ID合成默认档案",
			before["ok"] && before["legacy_only"]==1 &&
			sizeof(before["characters"])==1 &&
			before["characters"][0]["id"]==account_id,
			"旧人物没有被识别为默认档案");
		check("仅查询旧账号不会创建迁移文件",
			Stdio.file_size(account_file(account_id))<=0,
			"读取旧账号时发生了隐式写盘");

		mapping created = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi");
		if(created["ok"] && mappingp(created["character"]))
			character_id = (string)created["character"]["id"];
		check("新增方士建立独立物理档案和原子账号索引",
			created["ok"] && character_id!="" &&
			Stdio.file_size(player_file(character_id))>0 &&
			Stdio.file_size(account_file(account_id))>0,
			(string)(created["message"] || "创建结果不完整"));
		check("新人物等待原职业命令完成初始化",
			created["bootstrap_command"]=="choice_profe third/fangshi" &&
			ACCOUNT_CHARACTERD->query_bootstrap_command(
				account_id,character_id)=="choice_profe third/fangshi",
			"没有复用 choice_profe 职业初始化入口");

		mapping after = ACCOUNT_CHARACTERD->
			query_account_characters(account_id);
		check("默认旧人物与新人物同时出现在账号列表",
			after["ok"] && after["legacy_only"]==0 &&
			sizeof(after["characters"])==2 &&
			after["characters"][0]["id"]==account_id &&
			after["characters"][1]["profession_id"]=="fangshi",
			"账号索引顺序或人物摘要错误");
		check("账号授权只允许选择自己的人物",
			ACCOUNT_CHARACTERD->account_owns_character(
				account_id,character_id) &&
			!ACCOUNT_CHARACTERD->account_owns_character(
				account_id,"xd99notownedcharacter"),
			"人物归属校验可被越权");

		string index_source = Stdio.read_file(account_file(account_id));
		Stdio.write_file(account_file(account_id)+".bak",index_source);
		Stdio.write_file(account_file(account_id),"{broken");
		ACCOUNT_CHARACTERD->drop_test_account_cache(account_id);
		mapping backup_recovered = ACCOUNT_CHARACTERD->
			query_account_characters(account_id);
		Stdio.write_file(account_file(account_id)+".bak","{broken-too");
		ACCOUNT_CHARACTERD->drop_test_account_cache(account_id);
		mapping corrupt_closed = ACCOUNT_CHARACTERD->
			query_account_characters(account_id);
		object corrupt_login_probe = clone(GAMELIB_USER);
		corrupt_login_probe->set_name(account_id);
		corrupt_login_probe->set_project("gamelib");
		corrupt_login_probe->restore();
		object corrupt_login_key = ACCOUNT_CHARACTERD->
			query_account_runtime_mutex(account_id)->lock();
		int corrupt_login_denied = !ACCOUNT_CHARACTERD->
			prepare_character_login_locked(corrupt_login_probe);
		destruct(corrupt_login_key);
		destruct(corrupt_login_probe);
		Stdio.write_file(account_file(account_id),index_source);
		rm(account_file(account_id)+".bak");
		ACCOUNT_CHARACTERD->drop_test_account_cache(account_id);
		check("账号索引优先从有效备份恢复且双重损坏时失败关闭",
			backup_recovered["ok"] &&
			sizeof(backup_recovered["characters"])==2 &&
			!corrupt_closed["ok"] && corrupt_login_denied,
			"损坏索引被误当成旧账号或有效备份没有生效");

		mapping duplicate = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi");
		mapping pending_other = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","tianxiang");
		mapping invalid = ACCOUNT_CHARACTERD->create_character(
			account_id,"human","fangshi");
		check("同账号同职业不能重复占用档案",
			!duplicate["ok"] && !pending_other["ok"] &&
			search((string)duplicate["message"],"已经拥有")!=-1 &&
			search((string)pending_other["message"],"待创建")!=-1,
			"待初始化人物仍可重复或连续创建");
		check("伪造阵营职业组合被服务端拒绝",
			!invalid["ok"],"非法职业组合通过校验");

		restored = clone(GAMELIB_USER);
		restored->set_name(character_id);
		restored->set_project("gamelib");
		int restored_ok = restored->restore();
		check("新人物存档可独立恢复且继承账号密码",
			restored_ok && restored->query_account_owner()==account_id &&
			restored->query_password()==password &&
			(!restored->query_profeId() || restored->query_profeId()==""),
			"归属、密码或空白职业状态错误");
		restored->set_account_owner("xd99testunitoutsider");
		restored->save_with_result();
		int forged_owner_denied = !ACCOUNT_CHARACTERD->
			account_owns_character(account_id,character_id);
		restored->set_account_owner(account_id);
		restored->save_with_result();
		check("子人物物理档案归属被篡改时拒绝选角",
			forged_owner_denied && ACCOUNT_CHARACTERD->
				account_owns_character(account_id,character_id),
			"只校验索引而没有校验物理档案归属");

		mapping changed = ACCOUNT_CHARACTERD->change_account_password(
			legacy,"testunit99");
		string root_source = Stdio.read_file(player_file(account_id));
		string child_source = Stdio.read_file(player_file(character_id));
		string root_backup = Stdio.read_file(player_file(account_id)+".bak");
		string child_backup = Stdio.read_file(player_file(character_id)+".bak");
		check("账号密码修改原子同步到旧人物和新增人物",
			changed["ok"] && changed["updated"]==2 &&
			legacy->query_password()=="testunit99" &&
			search(root_source,"password \"testunit99\"")!=-1 &&
			search(child_source,"password \"testunit99\"")!=-1 &&
			(!root_backup || search(root_backup,
				"password \"testunit88\"")==-1) &&
			(!child_backup || search(child_backup,
				"password \"testunit88\"")==-1),
			"多人物密码没有保持账号级一致");

		string http_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/http_api_daemon.pike");
		string account_http_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/account_characters.pike");
		string recovery_source = Stdio.read_file(ROOT+
			"/lowlib/system/cmds/login_band.pike");
		string vue_source = Stdio.read_file(ROOT+"/vue_source/js/app.js");
		check("账号接口、令牌授权、多职业共存和旧后端回退同时存在",
			http_source && account_http_source && recovery_source &&
			vue_source &&
			search(http_source,"/api/account/login")!=-1 &&
			search(http_source,"DATA_ROOT + \"u/\"")!=-1 &&
			search(account_http_source,
				"account_owns_character(account_id,character_id)")!=-1 &&
			search(account_http_source,
				"ACCOUNT_SESSION_PER_ACCOUNT_LIMIT")!=-1 &&
			search(account_http_source,
				"请使用POST读取人物档案")!=-1 &&
			search(account_http_source,
				"disconnect_account_siblings")==-1 &&
			search(vue_source,"/api/account/characters?token=")==-1 &&
			search(recovery_source,"change_account_password(user_ob,psw)")!=-1 &&
			search(vue_source,"error.status === 404 || error.status === 501")!=-1,
			"新接口安全边界或滚动部署兼容缺失");

		array(string) compile_files = ({
			"/gamelib/single/daemons/account_characterd.pike",
			"/gamelib/single/daemons/http_api_daemon.pike",
			"/gamelib/clone/user.pike",
		});
		array(string) compile_failures = ({});
		foreach(compile_files,string file){
			mixed compile_err = catch{ compile_file(ROOT+file); };
			if(compile_err)
				compile_failures += ({file+": "+describe_error(compile_err)});
		}
		check("多人物后端文件可由真实Pike运行时编译",
			!sizeof(compile_failures),compile_failures*" | ");
	};
	if(err)
		check("多人物测试运行时无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(restored)
		destruct(restored);
	if(legacy)
		destruct(legacy);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	if(character_id!="")
		cleanup_player(character_id);
	cleanup_player(account_id);
	werror("注册账号多人物：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
