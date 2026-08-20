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
	string case_account_id = "xd99CaseUnitLSQ";
	string case_account_lower = lower_case(case_account_id);
	string character_id = "";
	object|zero legacy = 0;
	object|zero restored = 0;
	object|zero case_player = 0;
	object|zero original_player = this_player();
	werror("\n========== 注册账号多人物测试 ==========\n");
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	NAMESD->remove_test_profile_name("testunitA1");
	NAMESD->remove_test_profile_name("testunitB2");
	ACCOUNT_CHARACTERD->remove_test_account(case_account_id);
	ACCOUNT_CHARACTERD->remove_test_account(case_account_lower);
	cleanup_player(case_account_id);
	cleanup_player(case_account_lower);
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

		mapping unnamed_rejected = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi","无名方士","female","h_female1");
		mapping forged_avatar_rejected = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi","testunitA1","female","m_female1");
		check("新建人物必须通过姓名与头像服务端校验",
			!unnamed_rejected["ok"] && !forged_avatar_rejected["ok"] &&
			search((string)unnamed_rejected["message"],"无名")!=-1 &&
			search((string)forged_avatar_rejected["message"],"不匹配")!=-1,
			"无名或跨阵营伪造头像通过了创建接口");

		mapping created = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi","testunitA1","female","h_female1");
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
		check("新人物创建时姓名、性别和头像已经原子保存",
			created["character"]["name_cn"]=="testunitA1" &&
			created["character"]["sex"]=="female" &&
			created["character"]["avatar_id"]=="h_female1" &&
			created["character"]["profile_complete"],
			"创建后仍留下无名、无头像或资料不完整状态");

		mapping legacy_index = (mapping)Standards.JSON.decode(
			Stdio.read_file(account_file(account_id)));
		m_delete(legacy_index,"revision");
		legacy_index["version"] = 1;
		Stdio.write_file(account_file(account_id),
			Standards.JSON.encode(legacy_index));
		ACCOUNT_CHARACTERD->drop_test_account_cache(account_id);
		mapping revision_guard = ACCOUNT_CHARACTERD->
			test_account_revision_conflict_guard(account_id);
		check("旧版无revision索引可升级且跨Worker旧快照不会覆盖",
			(int)revision_guard["first_saved"]==1 &&
			(int)revision_guard["stale_rejected"]==1 &&
			(string)revision_guard["marker"]=="first" &&
			(int)revision_guard["revision"]==1,
			sprintf("revision guard=%O",revision_guard));

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

		mapping bookmark_first = ACCOUNT_CHARACTERD->
			create_character_bookmark(account_id,character_id,password);
		mapping bookmark_second = ACCOUNT_CHARACTERD->
			create_character_bookmark(account_id,character_id,password);
		string bookmark_token = (string)(bookmark_first["bookmark_token"] || "");
		mapping bookmark_verified = ACCOUNT_CHARACTERD->
			verify_character_bookmark(account_id,character_id,
				bookmark_token,password);
		mapping bookmark_wrong_password = ACCOUNT_CHARACTERD->
			verify_character_bookmark(account_id,character_id,
				bookmark_token,"wrongPassword");
		mapping bookmark_wrong_character = ACCOUNT_CHARACTERD->
			verify_character_bookmark(account_id,account_id,
				bookmark_token,password);
		check("人物直达书签使用独立随机令牌且重复签发不破坏旧链接",
			bookmark_first["ok"] && bookmark_second["ok"] &&
			sizeof(bookmark_token)==64 && bookmark_verified["ok"] &&
			!bookmark_wrong_password["ok"] &&
			!bookmark_wrong_character["ok"],
			"书签未绑定人物/账号密码，或新书签错误吊销旧链接");
		string bookmark_index_source = Stdio.read_file(
			account_file(account_id));
		check("人物直达书签磁盘只保存摘要而不保存原始凭证",
			bookmark_index_source &&
			search(bookmark_index_source,bookmark_token)==-1 &&
			search(bookmark_index_source,"token_digest")!=-1 &&
			search(bookmark_index_source,"auth_proof")!=-1,
			"原始直达凭证被写入账号索引或缺少密码变更失效证明");
		mapping bookmark_revoked = ACCOUNT_CHARACTERD->
			revoke_character_bookmarks(account_id,character_id);
		mapping bookmark_after_revoke = ACCOUNT_CHARACTERD->
			verify_character_bookmark(account_id,character_id,
				bookmark_token,password);
		check("人物直达书签可按人物一次性撤销且不依赖浏览器会话",
			bookmark_revoked["ok"] &&
			(int)bookmark_revoked["revoked"]==2 &&
			!bookmark_after_revoke["ok"],
			"撤销后旧书签仍可使用或遗漏同人物凭证");

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

		mapping pending_same = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi");
		mapping pending_other = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","tianxiang");
		mapping invalid = ACCOUNT_CHARACTERD->create_character(
			account_id,"human","fangshi");
		check("待初始化人物阻止连续占用空白档案",
			!pending_same["ok"] && !pending_other["ok"] &&
			search((string)pending_same["message"],"待创建")!=-1 &&
			search((string)pending_other["message"],"待创建")!=-1,
			"待初始化人物仍可连续创建");
		check("伪造阵营职业组合被服务端拒绝",
			!invalid["ok"],"非法职业组合通过校验");

		restored = clone(GAMELIB_USER);
		restored->set_name(character_id);
		restored->set_project("gamelib");
		int restored_ok = restored->restore();
		check("新人物存档可独立恢复且继承账号密码",
			restored_ok && restored->query_account_owner()==account_id &&
			restored->query_password()==password &&
			restored->have_name_cn()=="testunitA1" &&
			restored->sex=="female" &&
			restored->user_pic=="h_female1" &&
			(!restored->query_profeId() || restored->query_profeId()==""),
			"归属、密码或空白职业状态错误");
		restored->set_password("childOnly88");
		restored->set_account_owner("xd99testunitoutsider");
		restored->save_with_result();
		HTTP_APID->invalidate_user_password_cache(character_id);
		int forged_owner_denied = !ACCOUNT_CHARACTERD->
			account_owns_character(account_id,character_id);
		int forged_legacy_login_denied = !HTTP_APID->
			test_character_login_password_matches(
				character_id,password,"");
		restored->set_password(password);
		restored->set_account_owner(account_id);
		restored->save_with_result();
		HTTP_APID->invalidate_user_password_cache(character_id);
		check("子人物物理档案归属被篡改时拒绝选角",
			forged_owner_denied && forged_legacy_login_denied &&
			ACCOUNT_CHARACTERD->
				account_owns_character(account_id,character_id),
			"选角或老JSP主账号密码只校验了单侧归属");

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

		restored->set_password("childLegacy99");
		restored->save_with_result();
		HTTP_APID->invalidate_user_password_cache(character_id);
		HTTP_APID->invalidate_user_password_cache(account_id);
		check("老JSP共享角色接受主账号密码且人物ID大小写敏感",
			HTTP_APID->test_character_login_password_matches(
				character_id,"childLegacy99","") &&
			HTTP_APID->test_character_login_password_matches(
				character_id,"testunit99","") &&
			!HTTP_APID->test_character_login_password_matches(
				upper_case(character_id),"testunit99","") &&
			!HTTP_APID->test_character_login_password_matches(
				character_id,"wrongPassword","") ,
			"共享账号、旧角色密码或大小写隔离校验错误");
		restored->set_password("testunit99");
		restored->save_with_result();
		HTTP_APID->invalidate_user_password_cache(character_id);

		case_player = create_legacy_player(case_account_id,"CasePass2026");
		HTTP_APID->invalidate_user_password_cache(case_account_id);
		HTTP_APID->invalidate_user_password_cache(case_account_lower);
		int case_sensitive_filesystem =
			Stdio.file_size(player_file(case_account_lower))<=0;
		check("历史大写人物档案只按精确ID认证",
			HTTP_APID->get_user_password(case_account_id)=="CasePass2026" &&
			HTTP_APID->test_character_login_password_matches(
				case_account_id,"CasePass2026","") &&
			Stdio.file_size(player_file(case_account_id))>0 &&
			(!case_sensitive_filesystem ||
			 (!HTTP_APID->get_user_password(case_account_lower) &&
			  !HTTP_APID->test_character_login_password_matches(
				case_account_lower,"CasePass2026","") &&
			  Stdio.file_size(player_file(case_account_lower))<=0)),
			"大写老档被强制转小写、串号或错误命中不存在档案");

		object init_room = (object)(ROOT+"/gamelib/d/init");
		mixed first_entry_err = catch{
			restored->move(init_room);
			set_this_player(restored);
			init_room->choice_profe("third/fangshi");
			init_room->start("third");
		};
		if(original_player)
			set_this_player(original_player);
		else
			set_this_player(this_object());
		check("新建人物首次进入可真实完成职业初始化并进入出生点",
			!first_entry_err && restored->query_profeId()=="fangshi" &&
			restored->query_raceId()=="third" && environment(restored) &&
			environment(restored)!=init_room,
			first_entry_err ? describe_error(first_entry_err)+" "+
				describe_backtrace(first_entry_err) :
				"职业、阵营或出生点初始化不完整");

		int initialized_saved = restored->save_with_result();
		mapping duplicate_name = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi","testunitA1","female","h_female2");
		check("并发安全姓名登记拒绝账号内外重复姓名",
			!duplicate_name["ok"] &&
			search((string)duplicate_name["message"],"已经有人")!=-1,
			"已登记姓名仍被第二个人物占用");
		mapping repeated = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi");
		mapping repeated_list = ACCOUNT_CHARACTERD->
			query_account_characters(account_id);
		int fangshi_count = 0;
		foreach((array)(repeated_list["characters"] || ({})),
			mapping summary){
			if(summary["profession_id"]=="fangshi")
				fangshi_count++;
		}
		check("同账号可重复创建同职业且只保留二十人物总上限",
			initialized_saved && repeated["ok"] &&
			repeated_list["ok"] &&
			sizeof((array)repeated_list["characters"])==3 &&
			fangshi_count==2 &&
			ACCOUNT_CHARACTERD->query_character_limit()==30,
			(string)(repeated["message"] ||
				"重复职业创建或总上限错误"));

		legacy->name_cn = "";
		legacy->sex = "male";
		legacy->user_pic = "";
		legacy->set_pic_ok = 0;
		legacy->save_with_result();
		mapping legacy_profile_before = ACCOUNT_CHARACTERD->
			query_character_profile_status(legacy);
		mapping legacy_profile_saved = ACCOUNT_CHARACTERD->
			complete_character_profile(legacy,"testunitB2","male","h_male1");
		mapping legacy_profile_after = ACCOUNT_CHARACTERD->
			query_character_profile_status(legacy);
		mapping legacy_profile_second = ACCOUNT_CHARACTERD->
			complete_character_profile(legacy,"testunitOther","female","h_female1");
		check("旧无名人物登录后可补全资料且不能借入口二次改名换头像",
			legacy_profile_before["profile_needs_name"] &&
			legacy_profile_before["profile_needs_avatar"] &&
			legacy_profile_saved["ok"] &&
			legacy_profile_after["profile_complete"] &&
			legacy->have_name_cn()=="testunitB2" &&
			legacy->user_pic=="h_male1" &&
			legacy_profile_second["ok"] &&
			legacy->have_name_cn()=="testunitB2" &&
			legacy->user_pic=="h_male1",
			"存量无名档案无法安全补全或已完整资料可被覆盖");

		string http_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/http_api_daemon.pike");
		string account_http_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/_http_api_mod/account_characters.pike");
		string recovery_source = Stdio.read_file(ROOT+
			"/lowlib/system/cmds/login_band.pike");
		string vue_source = Stdio.read_file(ROOT+"/vue_source/js/app.js");
		string user_count_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/user_countd.pike");
		check("账号接口、令牌授权、多职业共存和旧后端回退同时存在",
			http_source && account_http_source && recovery_source &&
			vue_source &&
			search(http_source,"/api/account/login")!=-1 &&
			search(http_source,"/api/account/bookmark/create")!=-1 &&
			search(http_source,"/api/account/bookmark/open")!=-1 &&
			search(http_source,"/api/account/bookmark/revoke")!=-1 &&
			search(http_source,"DATA_ROOT + \"u/\"")!=-1 &&
			search(account_http_source,
				"account_owns_character(account_id,character_id)")!=-1 &&
			search(account_http_source,
				"ACCOUNT_SESSION_PER_ACCOUNT_LIMIT")!=-1 &&
			search(account_http_source,
				"authenticated_character_password_matches")!=-1 &&
			search(account_http_source,
				"create_character_bookmark")!=-1 &&
			search(account_http_source,
				"verify_character_bookmark")!=-1 &&
			search(account_http_source,
				"请完整选择人物姓名、性别和头像")!=-1 &&
			search(account_http_source,
				"请使用POST读取人物档案")!=-1 &&
			search(account_http_source,
				"disconnect_account_siblings")==-1 &&
			search(vue_source,"/api/account/characters?token=")==-1 &&
			search(recovery_source,"change_account_password(user_ob,psw)")!=-1 &&
			search(vue_source,"error.status === 404 || error.status === 501")!=-1,
			"新接口安全边界或滚动部署兼容缺失");
		check("注册统计目录缺失时自动创建且写入失败不再中断初始化",
			user_count_source &&
			search(user_count_source,"append_database_log")!=-1 &&
			search(user_count_source,"Stdio.mkdirhier(directory)")!=-1 &&
			search(user_count_source,
				"[USER_COUNTD] %s log append failed")!=-1,
			"注册/每日统计仍可能因db_log目录缺失抛出异常");

		array(string) compile_files = ({
			"/gamelib/single/daemons/account_characterd.pike",
			"/gamelib/single/daemons/http_api_daemon.pike",
			"/gamelib/single/daemons/user_countd.pike",
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
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("多人物测试运行时无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(restored)
		destruct(restored);
	if(legacy)
		destruct(legacy);
	if(case_player)
		destruct(case_player);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	if(character_id!="")
		cleanup_player(character_id);
	cleanup_player(account_id);
	NAMESD->remove_test_profile_name("testunitA1");
	NAMESD->remove_test_profile_name("testunitB2");
	ACCOUNT_CHARACTERD->remove_test_account(case_account_id);
	ACCOUNT_CHARACTERD->remove_test_account(case_account_lower);
	cleanup_player(case_account_id);
	cleanup_player(case_account_lower);
	werror("注册账号多人物：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
