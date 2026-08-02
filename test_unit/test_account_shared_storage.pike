#!/usr/bin/env pike
/** 同账号多角色在线与独立共享仓库防复制回归。 */

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

string storage_file(string account_id)
{
	return DATA_ROOT+"accounts/"+
		account_id[sizeof(account_id)-2..]+"/"+
		account_id+".storage.json";
}

void cleanup_player(string userid)
{
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_legacy_player(string userid,string password)
{
	object player = clone(GAMELIB_USER);
	player->set_name(userid);
	player->set_password(password);
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn = "共享仓库测试人物";
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->packageLevel = 20;
	player->packaged_items = ({({
		"tongkuangshi","铜矿石","铜矿石",
		"material/tongkuangshi",0,0,150,
	})});
	player->save_with_result();
	return player;
}

int count_personal_id(object player,string item_id)
{
	int count = 0;
	if(!player || !arrayp(player->packaged_items))
		return 0;
	for(int i=0;i<sizeof(player->packaged_items);i++){
		array one = player->packaged_items[i];
		if(arrayp(one) && sizeof(one)>7 && one[7]==item_id)
			count++;
	}
	return count;
}

int main()
{
	string account_id = "xd99testunitshared";
	string child_id = "";
	string item_id = "";
	string valid_storage = "";
	object|zero root_player = 0;
	object|zero root_relogin = 0;
	object|zero child_player = 0;
	object original_player = this_player();
	array(object) extra_players = ({});
	werror("\n========== 账号共享仓库测试 ==========\n");
	ACCOUNT_STORAGED->remove_test_storage(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player(account_id);
	mixed err = catch{
		root_player = create_legacy_player(account_id,"testunit88");
		mapping created = ACCOUNT_CHARACTERD->create_character(
			account_id,"third","fangshi");
		if(created["ok"])
			child_id = (string)created["character"]["id"];
		check("测试账号建立两个独立人物档案",
			created["ok"] && child_id!="",
			(string)(created["message"] || "子人物创建失败"));

		mapping initial = ACCOUNT_STORAGED->query_storage(root_player);
		if(initial["ok"] && sizeof((array)initial["personal_items"]))
			item_id = (string)initial["personal_items"][0][7];
		check("读取共享仓库只为旧仓库物品追加永久唯一ID",
			initial["ok"] && item_id!="" &&
			Stdio.file_size(storage_file(account_id))<=0 &&
			count_personal_id(root_player,item_id)==1,
			"旧人物仓库被迁移或唯一ID没有持久化");

		// 同一随机ID即使出现在其他存档字段，也不能冒充个人仓库所有权。
		root_player->desc = "事务恢复干扰值"+item_id;
		mapping interrupted_in = ACCOUNT_STORAGED->transfer_to_shared(
			root_player,item_id,"after_personal_save");
		ACCOUNT_STORAGED->drop_test_cache(account_id);
		mapping recovered_in = ACCOUNT_STORAGED->query_storage(root_player);
		check("人物转共享中断按仓库字段精确恢复且不受其他存档文本干扰",
			interrupted_in["pending"] && recovered_in["ok"] &&
			recovered_in["used"]==1 &&
			count_personal_id(root_player,item_id)==0 &&
			recovered_in["items"][0]["id"]==item_id,
			"中断恢复造成物品丢失或两端并存");

		mapping duplicate = ACCOUNT_STORAGED->transfer_to_shared(
			root_player,item_id);
		mapping after_duplicate = ACCOUNT_STORAGED->query_storage(root_player);
		check("重复点击转入请求不会复制或转移其他同名物品",
			!duplicate["ok"] && after_duplicate["used"]==1,
			"幂等边界没有拒绝已完成的物品ID");

		mapping interrupted_out = ACCOUNT_STORAGED->transfer_to_personal(
			root_player,item_id,"after_personal_save");
		ACCOUNT_STORAGED->drop_test_cache(account_id);
		mapping recovered_out = ACCOUNT_STORAGED->query_storage(root_player);
		check("共享转人物在目标保存后中断只确认一次",
			interrupted_out["pending"] && recovered_out["ok"] &&
			recovered_out["used"]==0 &&
			count_personal_id(root_player,item_id)==1,
			"恢复时重复写入人物仓库或错误回滚");

		mapping normal_in = ACCOUNT_STORAGED->transfer_to_shared(
			root_player,item_id);
		child_player = clone(GAMELIB_USER);
		child_player->set_name(child_id);
		child_player->set_project("gamelib");
		child_player->restore();
		child_player->set_raceId("third");
		child_player->set_profeId("fangshi");
		child_player->setup_player("third","fangshi");
		child_player->packageLevel = 20;
		child_player->save_with_result();
		mapping normal_out = ACCOUNT_STORAGED->transfer_to_personal(
			child_player,item_id);
		mapping final_state = ACCOUNT_STORAGED->query_storage(child_player);
		check("不同职业角色通过独立共享仓库移动而不是复制物品",
			normal_in["ok"] && normal_out["ok"] &&
			final_state["used"]==0 &&
			count_personal_id(root_player,item_id)==0 &&
			count_personal_id(child_player,item_id)==1,
			"账号内跨人物移动后唯一ID总数不是1");

		mapping put_back = ACCOUNT_STORAGED->transfer_to_shared(
			child_player,item_id);
		mapping before_reconcile = ACCOUNT_STORAGED->
			query_storage(child_player);
		child_player->packaged_items += ({copy_value(
			before_reconcile["items"][0]["data"])});
		child_player->save_with_result();
		int reconciled = ACCOUNT_STORAGED->
			reconcile_player_login(child_player);
		mapping after_reconcile = ACCOUNT_STORAGED->
			query_storage(child_player);
		check("登录恢复旧角色备份时删除共享仓库已有ID的克隆影子",
			put_back["ok"] && reconciled &&
			after_reconcile["used"]==1 &&
			count_personal_id(child_player,item_id)==0,
			"角色旧备份与共享仓库同时保留了相同物品ID");

		object storage_ui =
			(object)(ROOT+"/gamelib/cmds/account_storage.pike");
		object storage_take =
			(object)(ROOT+"/gamelib/cmds/account_storage_withdraw.pike");
		object storage_put =
			(object)(ROOT+"/gamelib/cmds/account_storage_deposit.pike");
		child_player->move(ROOT+"/gamelib/d/kunlunshan/wuge");
		set_this_player(child_player);
		storage_ui->main(0);
		storage_ui->main("personal");
		storage_ui->main("shared");
		storage_ui->main("put 999");
		storage_ui->main("take 999");
		storage_take->main(item_id+" 0");
		mapping ui_taken = ACCOUNT_STORAGED->query_storage(child_player);
		int ui_taken_personal =
			count_personal_id(child_player,item_id);
		storage_put->main(item_id+" 0");
		mapping ui_returned = ACCOUNT_STORAGED->query_storage(child_player);
		if(original_player)
			set_this_player(original_player);
		else
			set_this_player(this_object());
		check("共享仓库新旧入口、分页和连续取放真实运行",
			ui_taken["used"]==0 &&
			ui_taken_personal==1 &&
			count_personal_id(child_player,item_id)==0 &&
			ui_returned["used"]==1 &&
			ui_returned["items"][0]["id"]==item_id,
			"分页界面或带页码的连续取放没有保持唯一物品");
		valid_storage = Stdio.read_file(storage_file(account_id));
		Stdio.write_file(storage_file(account_id)+".bak",valid_storage);
		Stdio.write_file(storage_file(account_id),"{broken");
		ACCOUNT_STORAGED->drop_test_cache(account_id);
		mapping corrupt_health = ACCOUNT_STORAGED->
			query_storage_health(account_id);
		check("共享仓库主文件损坏时不自动恢复旧备份复活装备",
			put_back["ok"] && !corrupt_health["ok"],
			"过期备份被自动作为权威仓库读取");
		Stdio.write_file(storage_file(account_id),valid_storage);
		rm(storage_file(account_id)+".bak");
		ACCOUNT_STORAGED->drop_test_cache(account_id);

		object root_mutex = ACCOUNT_CHARACTERD->
			query_account_runtime_mutex(account_id);
		object child_mutex = ACCOUNT_CHARACTERD->
			query_account_runtime_mutex(child_id);
		check("同一注册账号的不同人物复用同一运行时互斥锁",
			root_mutex==child_mutex,
			"HTTP线程仍按人物ID并发执行");
		check("账号同时在线上限从配置热读取且当前默认五个人物",
			ACCOUNT_CHARACTERD->query_max_online_characters()==5,
			"account_characters.conf没有生效");
		object root_key = root_mutex->lock();
		int root_login = ACCOUNT_CHARACTERD->
			prepare_character_login_locked(root_player);
		destruct(root_key);
		object child_key = child_mutex->lock();
		int child_login = ACCOUNT_CHARACTERD->
			prepare_character_login_locked(child_player);
		destruct(child_key);
		array(string) dual_online = ACCOUNT_CHARACTERD->
			query_active_characters(account_id);
		check("配置允许时同账号不同职业人物可以同时在线",
			root_login && child_login &&
			search(dual_online,account_id)!=-1 &&
			search(dual_online,child_id)!=-1 &&
			sizeof(dual_online)==2,
			"第二人物登录错误清退了不同职业人物");

		root_relogin = clone(GAMELIB_USER);
		root_relogin->set_name(account_id);
		root_relogin->set_project("gamelib");
		root_relogin->restore();
		object relogin_key = root_mutex->lock();
		int same_character_login = ACCOUNT_CHARACTERD->
			prepare_character_login_locked(root_relogin);
		destruct(relogin_key);
		array(string) after_same_login = ACCOUNT_CHARACTERD->
			query_active_characters(account_id);
		check("同一人物共用同一存档且任何配置下都不能双对象在线",
			same_character_login && !objectp(root_player) &&
			sizeof(after_same_login)==2 &&
			search(after_same_login,account_id)!=-1 &&
			search(after_same_login,child_id)!=-1,
			"同一人物重复登录可能并发保存同一个档案");

		array(array(string)) extra_professions = ({
			({"human","yushi"}),
			({"human","zhuxian"}),
			({"monst","kuangyao"}),
			({"monst","wuyao"}),
		});
		int extra_login_ok = 1;
		foreach(extra_professions,array(string) pair){
			mapping extra_created = ACCOUNT_CHARACTERD->create_character(
				account_id,pair[0],pair[1]);
			if(!extra_created["ok"]){
				extra_login_ok = 0;
				continue;
			}
			string extra_id = (string)extra_created["character"]["id"];
			object extra = clone(GAMELIB_USER);
			extra->set_name(extra_id);
			extra->set_project("gamelib");
			extra->restore();
			extra->set_raceId(pair[0]);
			extra->set_profeId(pair[1]);
			extra->setup_player(pair[0],pair[1]);
			extra->save_with_result();
			extra_players += ({extra});
			object extra_key = root_mutex->lock();
			if(!ACCOUNT_CHARACTERD->prepare_character_login_locked(extra))
				extra_login_ok = 0;
			destruct(extra_key);
		}
		array(string) five_online = ACCOUNT_CHARACTERD->
			query_active_characters(account_id);
		check("第六个不同职业登录时按默认五人上限清退最早人物",
			extra_login_ok && sizeof(five_online)==5 &&
			!objectp(child_player) && objectp(root_relogin),
			"默认五人物上限没有准确执行");

		ACCOUNT_CHARACTERD->set_test_online_limit(account_id,1);
		int evicted_for_single = ACCOUNT_CHARACTERD->
			enforce_online_limit_now();
		array(string) single_online = ACCOUNT_CHARACTERD->
			query_active_characters(account_id);
		check("配置切回一时热检查安全保存并清退四个超额人物",
			evicted_for_single==4 && sizeof(single_online)==1,
			"单人物安全模式没有恢复");
		ACCOUNT_CHARACTERD->set_test_online_limit(account_id,0);

		array(string) compile_files = ({
			"/gamelib/single/daemons/account_characterd.pike",
			"/gamelib/single/daemons/account_storaged.pike",
			"/gamelib/cmds/account_storage.pike",
			"/gamelib/cmds/account_storage_deposit.pike",
			"/gamelib/cmds/account_storage_withdraw.pike",
			"/lowlib/system/inherit/user.pike",
			"/lowlib/system/cmds/login_check.pike",
			"/gamelib/single/daemons/http_api_daemon.pike",
		});
		array(string) failures = ({});
		foreach(compile_files,string file){
			mixed compile_err = catch{ compile_file(ROOT+file); };
			if(compile_err)
				failures += ({file+": "+describe_error(compile_err)});
		}
		check("登录守卫与共享仓库文件由真实Pike运行时编译",
			!sizeof(failures),failures*" | ");
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		check("共享仓库测试运行时无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(child_player)
		destruct(child_player);
	if(root_relogin)
		destruct(root_relogin);
	if(root_player)
		destruct(root_player);
	foreach(extra_players,object extra){
		if(extra)
			destruct(extra);
	}
	ACCOUNT_STORAGED->remove_test_storage(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	if(child_id!="")
		cleanup_player(child_id);
	cleanup_player(account_id);
	werror("账号共享仓库：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
