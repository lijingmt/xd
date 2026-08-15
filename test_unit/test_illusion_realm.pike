#!/usr/bin/env pike
/** 新月幻境·S1资格、隔离、任务奖励与原档案回归回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

string player_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

void cleanup_player(string userid)
{
	if(!userid || search(userid,"testunitillusion")==-1)
		return;
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

object create_root(string account_id)
{
	object player = clone(GAMELIB_USER);
	player->set_name(account_id);
	player->set_password("testunit88");
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn = "S1测试账号";
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->save_with_result();
	return player;
}

int count_newmoon_items(object player)
{
	int count;
	foreach(all_inventory(player),object item)
		if(item && functionp(item->query_newmoon_collection_id) &&
		   (string)item->query_newmoon_collection_id()=="newmoon")
			count++;
	return count;
}

int all_newmoon_bound_to(object player,string account_id)
{
	int count;
	foreach(all_inventory(player),object item){
		if(!item || !functionp(item->query_newmoon_collection_id) ||
		   (string)item->query_newmoon_collection_id()!="newmoon")
			continue;
		count++;
		if(!functionp(item->query_newmoon_account_bind_owner) ||
		   (string)item->query_newmoon_account_bind_owner()!=account_id)
			return 0;
	}
	return count==10;
}

int main()
{
	string account_id = "xd99testunitillusion";
	string child_id = "";
	string second_id = "";
	string third_id = "";
	object|zero root = 0;
	object|zero child = 0;
	object|zero restored = 0;
	array(string) cleanup_ids = ({account_id});
	werror("\n========== 新月幻境·S1测试 ==========\n");
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_STORAGED->remove_test_storage(account_id);
	cleanup_player(account_id);
	mixed err = catch{
		mapping public_status = SEASONALD->query_public_status();
		check("首期稳定编号与展示名固定为S1",
			(string)public_status["illusion_id"]=="S1" &&
			(string)public_status["display_name"]=="新月幻境·S1" &&
			(int)public_status["duration_days"]==30 &&
			(int)public_status["entitlement_cost_suiyu"]==0 &&
			(int)public_status["extra_character_slot_cost_suiyu"]==100 &&
			(int)public_status["multi_character_unlock_cost_suiyu"]==500,
			sprintf("status=%O",public_status));
		mapping lifecycle_state = ([
			"phase":"active","starts_at":1000,"ends_at":2000,
		]);
		check("只有到期的进行中赛季会自动结算并自动关闭",
			SEASONALD->query_automatic_action_for_test(
				lifecycle_state,1999)=="" &&
			SEASONALD->query_automatic_action_for_test(
				lifecycle_state,2000)=="auto_settle" &&
			SEASONALD->query_automatic_action_for_test(
				(["phase":"settling"]),2000)=="auto_close" &&
			SEASONALD->query_automatic_action_for_test(
				(["phase":"closed"]),2000)=="" &&
			SEASONALD->query_automatic_action_for_test(
				(["phase":"registration","starts_at":1000,
					"ends_at":2000]),2000)=="",
			"自动开启或关闭后自动续期没有保持禁用");
		check("管理员可缩短或延长当前结束时间但不能改到开始之前",
			SEASONALD->query_end_time_valid_for_test(
				lifecycle_state,"active",1500)==1 &&
			SEASONALD->query_end_time_valid_for_test(
				lifecycle_state,"active",1000)==0 &&
			SEASONALD->query_end_time_valid_for_test(
				lifecycle_state,"closed",1500)==0 &&
			SEASONALD->query_end_time_valid_for_test(
				lifecycle_state,"active",1000+367*86400)==0,
			"结束时间边界校验错误");
		string login_source = Stdio.read_file(ROOT+
			"/lowlib/system/inherit/user.pike") || "";
		int season_login_pos = search(login_source,
			"seasonal_chard->reconcile_player_login");
		int storage_login_pos = search(login_source,
			"account_storaged->reconcile_player_login");
		check("登录先完成赛季回归再恢复永久服共享资产",
			season_login_pos!=-1 && storage_login_pos!=-1 &&
			season_login_pos<storage_login_pos,
			sprintf("season=%d storage=%d",season_login_pos,
				storage_login_pos));
		string season_source = Stdio.read_file(ROOT+
			"/gamelib/single/daemons/seasonal_chard.pike") || "";
		string player_command_source = Stdio.read_file(ROOT+
			"/gamelib/cmds/illusion_realm.pike") || "";
		string command_hook_source = Stdio.read_file(ROOT+
			"/lowlib/system/inherit/feature/cmds.pike") || "";
		check("在线自动结算获取账号锁且登录路径复用已持有锁",
			search(season_source,
				"query_account_runtime_mutex(\n\t\t(string)player->query_name())->lock()")!=-1 &&
			search(season_source,"settle_player_locked(player)")!=-1 &&
			search(login_source,
				"reconcile_player_login(this_object(),1)")!=-1,
			"结算可能与共享仓库写并发，或登录路径重复获取非递归账号锁");
		check("玩家回归入口只提示自动流程且不会重复获取账号锁",
			search(player_command_source,"SEASONALD->settle_player(me)")==-1 &&
			search(player_command_source,"系统自动安全回归")!=-1,
			"HTTP命令已持有账号锁时手工回归可能触发递归锁异常");
		check("幻境资格购买不重复获取非递归账号锁",
			search(player_command_source,
				"purchase_entitlement(me)")!=-1 &&
			search(season_source,
				"purchase_entitlement(object player)")!=-1 &&
			search(season_source,"purchase_entitlement(object player,\n")==-1,
			"Web购买可能在已持有的账号锁上再次加锁");
		check("S1资格免费激活且玩家界面不再显示付费购买",
			search(player_command_source,"资格当前免费永久激活")!=-1 &&
			search(player_command_source,"[免费激活:illusion_realm activate]")!=-1 &&
			search(player_command_source,"100碎玉永久加1格")!=-1 &&
			search(player_command_source,"补足累计500碎玉")!=-1,
			"免费配置仍被显示为0碎玉购买或付费门槛");
		check("关闭后保留有界窗口接住最后一批跨worker到达",
			search(season_source,"closed_reconcile_until = time()+180")!=-1 &&
			search(season_source,"time()<=closed_reconcile_until")!=-1 &&
			search(season_source,"time()+60")!=-1,
			"结算关闭竞态可能漏掉已接受但稍后才到达目标worker的人物");
		check("赛季家园在统一命令层拦截且旧书签不能绕过",
			search(command_hook_source,"search(verb,\"home_\")==0")!=-1 &&
			search(command_hook_source,
				"is_active_illusion_character(this_object())")!=-1,
			"仅限制地图移动会让远程家园商店命令跨世界搬运资产");
		mapping same_cycle_rollover = SEASONALD->preview_cycle_rollover();
		check("S1未关闭且配置编号未变化时拒绝误换期",
			!(int)same_cycle_rollover["ok"] &&
			(string)same_cycle_rollover["new_id"]=="S1",
			sprintf("rollover=%O",same_cycle_rollover));

		array(string) room_paths = ({
			"/gamelib/d/illusion_s1/moon_gate.pike",
			"/gamelib/d/illusion_s1/silver_path.pike",
			"/gamelib/d/illusion_s1/fog_forest.pike",
			"/gamelib/d/illusion_s1/mirror_lake.pike",
			"/gamelib/d/illusion_s1/broken_observatory.pike",
			"/gamelib/d/illusion_s1/echo_ruins.pike",
			"/gamelib/d/illusion_s1/star_bridge.pike",
			"/gamelib/d/illusion_s1/abyss_garden.pike",
			"/gamelib/d/illusion_s1/moon_palace.pike",
			"/gamelib/d/illusion_s1/newmoon_altar.pike",
			"/gamelib/d/illusion_s1/hidden_crater.pike",
		});
		int rooms_compile = 1;
		mapping(string:int) affinities = ([]);
		foreach(room_paths,string room_path){
			object room;
			mixed room_err = catch{ room=(object)(ROOT+room_path); };
			string one_affinity = MAP_WORKERD->query_affinity_key(room_path);
			if(room_err || !room || one_affinity=="")
				rooms_compile = 0;
			affinities[one_affinity]++;
		}
		check("S1地图全部可加载并按四个稳定章节使用多worker",
			rooms_compile && sizeof(affinities)==4 &&
			(int)affinities["illusion_s1:hub"]==1 &&
			(int)affinities["illusion_s1:silver"]==3 &&
			(int)affinities["illusion_s1:ruins"]==3 &&
			(int)affinities["illusion_s1:depths"]==4,
			sprintf("地图编译失败或affinity分组错误：%O",affinities));
		mapping hub_weight = MAP_WORKERD->query_affinity_weight_info(
			"illusion_s1:hub");
		mapping silver_weight = MAP_WORKERD->query_affinity_weight_info(
			"illusion_s1:silver");
		mapping ruins_weight = MAP_WORKERD->query_affinity_weight_info(
			"illusion_s1:ruins");
		mapping depths_weight = MAP_WORKERD->query_affinity_weight_info(
			"illusion_s1:depths");
		check("S1四个亲和组进入冷启动目录并使用真实房间权重",
			(int)hub_weight["ok"] && (int)hub_weight["static_weight"]==1 &&
			(int)silver_weight["ok"] &&
				(int)silver_weight["static_weight"]==3 &&
			(int)ruins_weight["ok"] &&
				(int)ruins_weight["static_weight"]==3 &&
			(int)depths_weight["ok"] &&
				(int)depths_weight["static_weight"]==4,
			sprintf("hub=%O silver=%O ruins=%O depths=%O",
				hub_weight,silver_weight,ruins_weight,depths_weight));
		check("S1同房间路由确定且不同章节不会错误合并",
			MAP_WORKERD->query_affinity_key(room_paths[1])==
				MAP_WORKERD->query_affinity_key(
					ROOT+room_paths[1]+"#987") &&
			MAP_WORKERD->query_affinity_key(room_paths[1])!=
				MAP_WORKERD->query_affinity_key(room_paths[4]) &&
			MAP_WORKERD->query_affinity_key(room_paths[4])!=
				MAP_WORKERD->query_affinity_key(room_paths[7]),
			"相同共享房间可能分裂，或各野外章节仍挤在同一worker");
		object player_command;
		object manager_command;
		mixed command_error = catch{
			player_command = (object)(ROOT+
				"/gamelib/cmds/illusion_realm.pike");
			manager_command = (object)(ROOT+
				"/gamelib/cmds/mgr_illusion_realm.pike");
		};
		check("玩家与管理员幻境命令均可在真实MUD环境加载",
			!command_error && player_command!=0 && manager_command!=0,
			command_error ? describe_error(command_error) : "命令对象为空");

		root = create_root(account_id);
		mapping denied = ACCOUNT_CHARACTERD->create_character(account_id,
			"human","jianxian","","","","illusion","S1");
		check("未永久解锁账号不能伪造S1人物创建",
			!(int)denied["ok"] &&
			search((string)denied["message"],"尚未永久解锁")!=-1,
			sprintf("denied=%O",denied));

		YUSHID->give_yushi(root,1000);
		int payment_before = YUSHID->query_physical_all_num(root);
		YUSHID->pay_yushi(root,5);
		root["/plus/illusion_entitlement_purchase"] = ([
			"version":1,"phase":"charged","request_id":"a"*64,
			"account_id":account_id,"illusion_id":"S1","cost":5,
			"before_wallet":0,"before_physical":payment_before,
			"created_at":time(),
		]);
		root->save_with_result();
		SEASONALD->reconcile_player_login(root);
		check("购买中断且资格未写入时登录自动原路退回碎玉",
			YUSHID->query_physical_all_num(root)==payment_before &&
			!sizeof((mapping)root["/plus/illusion_entitlement_purchase"]),
			"崩溃购买凭据未退款或未清理");

		string entitlement_request = "c"*64;
		mapping entitlement = ACCOUNT_CHARACTERD->grant_illusion_entitlement(
			account_id,"test",entitlement_request);
		mapping entitlement_again = ACCOUNT_CHARACTERD->
			grant_illusion_entitlement(account_id,"test",entitlement_request);
		check("永久资格幂等写入账号索引",
			(int)entitlement["ok"] && !(int)entitlement["already"] &&
			(int)entitlement_again["ok"] &&
			(int)entitlement_again["already"] &&
			(int)entitlement["entitlement"]["character_slots"]==1 &&
			!(int)entitlement["entitlement"]["multi_character_unlocked"],
			sprintf("first=%O second=%O",entitlement,entitlement_again));

		int matched_before = YUSHID->query_physical_all_num(root);
		YUSHID->pay_yushi(root,2);
		root["/plus/illusion_entitlement_purchase"] = ([
			"version":1,"phase":"charged",
			"request_id":entitlement_request,
			"account_id":account_id,"illusion_id":"S1","cost":2,
			"before_wallet":0,"before_physical":matched_before,
			"created_at":time(),
		]);
		root->save_with_result();
		SEASONALD->reconcile_player_login(root);
		check("资格请求号吻合时登录只清凭据而不错误退款",
			YUSHID->query_physical_all_num(root)==matched_before-2 &&
			!sizeof((mapping)root["/plus/illusion_entitlement_purchase"]),
			"已成功解锁的扣款被错误退回");

		int duplicate_before = YUSHID->query_physical_all_num(root);
		YUSHID->pay_yushi(root,2);
		root["/plus/illusion_entitlement_purchase"] = ([
			"version":1,"phase":"charged","request_id":"d"*64,
			"account_id":account_id,"illusion_id":"S1","cost":2,
			"before_wallet":0,"before_physical":duplicate_before,
			"created_at":time(),
		]);
		root->save_with_result();
		SEASONALD->reconcile_player_login(root);
		check("资格请求号不吻合时重复扣款会原路退回",
			YUSHID->query_physical_all_num(root)==duplicate_before &&
			!sizeof((mapping)root["/plus/illusion_entitlement_purchase"]),
			"并发或管理员解锁后的第二笔扣款未退回");

		mapping created = ACCOUNT_CHARACTERD->create_character(account_id,
			"human","jianxian","","","","illusion","S1");
		if((int)created["ok"]){
			child_id = (string)created["character"]["id"];
			cleanup_ids += ({child_id});
		}
		check("S1人物继续使用账号下唯一普通user档案",
			(int)created["ok"] && child_id!="" &&
			Stdio.file_size(player_file(child_id))>0,
			(string)(created["message"] || "创建失败"));

		child = clone(GAMELIB_USER);
		child->set_name(child_id);
		child->set_project("gamelib");
		child->restore();
		child->name_cn = "S1新月行者";
		child->set_raceId("human");
		child->set_profeId("jianxian");
		child->setup_player("human","jianxian");
		child->level = 69;
		child->set_att_by_level();
		SEASONALD->prepare_new_character(child);
		child->last_pos = "/gamelib/d/illusion_s1/silver_path.pike";
		SEASONALD->prepare_new_character(child);
		check("S1重新登录保留合法上次位置而首次越界位置回到营地",
			(string)child->last_pos==
				"/gamelib/d/illusion_s1/silver_path.pike" &&
			(string)child->relife==
			"/gamelib/d/illusion_s1/moon_gate.pike",
			sprintf("last=%s relife=%s",(string)child->last_pos,
				(string)child->relife));
		child->last_pos =
			"/gamelib/d/illusion_s1/removed_room.pike";
		child->relife =
			"/gamelib/d/illusion_s1/removed_bedroom.pike";
		object login_room = (object)(ROOT+"/gamelib/d/init");
		login_room->repair_invalid_login_positions(child,1);
		check("S1失效登录房间与复活点回退本期营地而非永恒主城",
			(string)child->last_pos==
				"/gamelib/d/illusion_s1/moon_gate.pike" &&
			(string)child->relife==
				"/gamelib/d/illusion_s1/moon_gate.pike",
			sprintf("last=%s relife=%s",(string)child->last_pos,
				(string)child->relife));
		mapping visited = ([]);
		for(int index=0;index<10;index++)
			visited["/gamelib/d/illusion_s1/test_"+(string)index+".pike"] = 1;
		child["/plus/illusion_realm/S1"] = ([
			"version":1,"joined_at":time(),"kills":650,"boss_kills":8,
			"team_kills":50,"visited":visited,"path":"hunter",
			"route_marks":([]),"claims":([]),
		]);
		object battle_room = (object)(ROOT+
			"/gamelib/d/illusion_s1/star_bridge.pike");
		child["/tmp/illusion_move_bypass"] = 1;
		child->move(battle_room);
		child->m_delete_foruser("/tmp/illusion_move_bypass");
		foreach(({"star_keeper","moon_general","newmoon_lord"}),
		   string boss_name){
			object boss = clone(ROOT+
				"/gamelib/clone/npc/illusion_s1/"+boss_name+".pike");
			boss->move(battle_room);
			SEASONALD->record_npc_kill(child,boss,1);
			destruct(boss);
		}
		mapping hunter_progress =
			child["/plus/illusion_realm/S1"];
		check("破阵路线按真实NPC文件识别三名不同首领",
			mappingp(hunter_progress["route_marks"]) &&
			sizeof((mapping)hunter_progress["route_marks"])==3,
			sprintf("marks=%O",hunter_progress["route_marks"]));
		hunter_progress["path"] = "pioneer";
		hunter_progress["route_marks"] = ([]);
		mapping last_secret = ([]);
		foreach(({"mirror_lake","hidden_crater","newmoon_altar"}),
		   string room_name){
			object secret_room = (object)(ROOT+
				"/gamelib/d/illusion_s1/"+room_name+".pike");
			child["/tmp/illusion_move_bypass"] = 1;
			child->move(secret_room);
			child->m_delete_foruser("/tmp/illusion_move_bypass");
			last_secret = SEASONALD->discover_route_secret_for_test(child);
		}
		mapping duplicate_secret =
			SEASONALD->discover_route_secret_for_test(child);
		check("寻星路线从三个真实房间取得三枚幂等隐藏月印",
			(int)last_secret["ok"] &&
			sizeof((mapping)hunter_progress["route_marks"])==3 &&
			(int)duplicate_secret["ok"] &&
			(int)duplicate_secret["already"],
			sprintf("last=%O duplicate=%O marks=%O",last_secret,
				duplicate_secret,hunter_progress["route_marks"]));
		hunter_progress["path"] = "hunter";
		hunter_progress["route_marks"] = ([
			"broken_star":1,"moon_guard":1,"newmoon_lord":1,
		]);
		child->save_with_result();
		mapping second_blocked = ACCOUNT_CHARACTERD->create_character(account_id,
			"human","yushi","","","","illusion","S1");
		check("每期首名免费但第二名必须先扩充永久栏位",
			!(int)second_blocked["ok"] &&
			search((string)second_blocked["message"],"栏位已用完")!=-1,
			sprintf("second=%O",second_blocked));
		string one_slot_request = "e"*64;
		mapping one_slot = ACCOUNT_CHARACTERD->
			grant_illusion_character_expansion(account_id,"one",
				one_slot_request,100);
		mapping one_slot_again = ACCOUNT_CHARACTERD->
			grant_illusion_character_expansion(account_id,"one",
				one_slot_request,100);
		check("100碎玉永久加1格且同请求重试不会重复累计",
			(int)one_slot["ok"] && !(int)one_slot["already"] &&
			(int)one_slot_again["ok"] && (int)one_slot_again["already"] &&
			(int)one_slot_again["same_request"] &&
			(int)one_slot["entitlement"]["character_slots"]==2 &&
			(int)one_slot["entitlement"]["expansion_spent_suiyu"]==100,
			sprintf("first=%O again=%O",one_slot,one_slot_again));
		int expansion_matched_before = YUSHID->query_physical_all_num(root);
		root["/plus/illusion_character_expansion_purchase"] = ([
			"version":1,"phase":"charged","request_id":one_slot_request,
			"account_id":account_id,"illusion_id":"S1","option":"one",
			"cost":100,"before_wallet":0,
			"before_physical":expansion_matched_before+100,"created_at":time(),
		]);
		root->save_with_result();
		SEASONALD->reconcile_player_login(root);
		check("扩容请求已写入账号索引时重启恢复只清凭据不误退款",
			YUSHID->query_physical_all_num(root)==expansion_matched_before &&
			!sizeof((mapping)root[
				"/plus/illusion_character_expansion_purchase"]),
			"已提交扩容被错误退款或恢复凭据未清理");
		int expansion_unmatched_before = YUSHID->query_physical_all_num(root);
		YUSHID->pay_yushi(root,100);
		root["/plus/illusion_character_expansion_purchase"] = ([
			"version":1,"phase":"charged","request_id":"1"*64,
			"account_id":account_id,"illusion_id":"S1","option":"one",
			"cost":100,"before_wallet":0,
			"before_physical":expansion_unmatched_before,"created_at":time(),
		]);
		root->save_with_result();
		SEASONALD->reconcile_player_login(root);
		check("扩容扣款未写入账号索引时重启自动原路退款",
			YUSHID->query_physical_all_num(root)==
				expansion_unmatched_before &&
			!sizeof((mapping)root[
				"/plus/illusion_character_expansion_purchase"]),
			"未提交扩容没有退款或恢复凭据未清理");
		mapping second_created = ACCOUNT_CHARACTERD->create_character(account_id,
			"human","yushi","","","","illusion","S1");
		if((int)second_created["ok"]){
			second_id = (string)second_created["character"]["id"];
			cleanup_ids += ({second_id});
		}
		mapping second_realm = second_id!="" ?
			ACCOUNT_CHARACTERD->query_character_realm(second_id) : ([]);
		check("扩充后允许同一期创建第二个独立人物但仍占账号总栏位",
			(int)second_created["ok"] && second_id!="" &&
			second_id!=child_id &&
			(string)second_realm["realm_type"]=="illusion" &&
			(string)second_realm["illusion_id"]=="S1" &&
			(int)ACCOUNT_CHARACTERD->query_character_limit()==30,
			sprintf("second=%O realm=%O",second_created,second_realm));
		object second_player = clone(GAMELIB_USER);
		second_player->set_name(second_id);
		second_player->set_project("gamelib");
		second_player->restore();
		second_player->name_cn = "S1御使行者";
		second_player->set_raceId("human");
		second_player->set_profeId("yushi");
		second_player->setup_player("human","yushi");
		second_player->level = 69;
		second_player->set_att_by_level();
		second_player->save_with_result();
		destruct(second_player);
		mapping third_blocked = ACCOUNT_CHARACTERD->create_character(account_id,
			"human","zhuxian","","","","illusion","S1");
		mapping wrong_remaining = ACCOUNT_CHARACTERD->
			grant_illusion_character_expansion(account_id,"all","f"*64,500);
		string all_slot_request = "f"*64;
		mapping all_slots = ACCOUNT_CHARACTERD->
			grant_illusion_character_expansion(account_id,"all",
				all_slot_request,400);
		mapping all_slots_again = ACCOUNT_CHARACTERD->
			grant_illusion_character_expansion(account_id,"all",
				all_slot_request,400);
		check("此前100碎玉全额抵扣且只需补400永久解锁多人物",
			!(int)third_blocked["ok"] && !(int)wrong_remaining["ok"] &&
			(int)wrong_remaining["expected_cost_suiyu"]==400 &&
			(int)all_slots["ok"] && !(int)all_slots["already"] &&
			(int)all_slots_again["ok"] && (int)all_slots_again["same_request"] &&
			(int)all_slots["entitlement"]["multi_character_unlocked"]==1 &&
			(int)all_slots["entitlement"]["expansion_spent_suiyu"]==500,
			sprintf("blocked=%O wrong=%O all=%O again=%O",third_blocked,
				wrong_remaining,all_slots,all_slots_again));
		mapping third_created = ACCOUNT_CHARACTERD->create_character(account_id,
			"human","zhuxian","","","","illusion","S1");
		if((int)third_created["ok"]){
			third_id = (string)third_created["character"]["id"];
			cleanup_ids += ({third_id});
		}
		check("永久多人物解锁后仍由账号30人物总上限约束",
			(int)third_created["ok"] && third_id!="" &&
			(int)ACCOUNT_CHARACTERD->query_character_limit()==30,
			sprintf("third=%O",third_created));

		mapping realm = ACCOUNT_CHARACTERD->query_character_realm(child_id);
		check("S1身份由账号索引判定并形成独立互动组",
			(string)realm["realm_type"]=="illusion" &&
			(string)realm["illusion_id"]=="S1" &&
			SEASONALD->query_character_group(child_id)=="illusion:S1" &&
			LOGICALZONED->query_user_group(child_id)=="illusion:S1",
			sprintf("realm=%O group=%s",realm,
				LOGICALZONED->query_user_group(child_id)));
		mapping active_realm = ([
			"realm_type":"illusion","illusion_state":"active",
			"illusion_id":"S1",
		]);
		check("S1进行中只允许区内移动且结算时冻结全部移动",
			SEASONALD->query_move_policy_for_test(active_realm,
				"/gamelib/d/congxianzhen/congxianzhenguangchang",
				"active")==2 &&
			SEASONALD->query_move_policy_for_test(active_realm,
				"/gamelib/d/illusion_s1/silver_path.pike","active")==0 &&
			SEASONALD->query_move_policy_for_test(active_realm,
				"/gamelib/d/illusion_s1/silver_path.pike","settling")==1,
			"移动边界或结算冻结策略不符合预期");
		check("S1家园房间路径始终按跨世界移动拒绝",
			SEASONALD->query_move_policy_for_test(active_realm,
				"/gamelib/d/home/template/main","active")==2 &&
			SEASONALD->query_move_policy_for_test(active_realm,
				"/gamelib/d/ninggedian/ninggedian","active")==2,
			"赛季人物可能从旧链接进入永恒家园或家园城区");
		check("换期后尚未登录回归的旧周期人物不能误入新周期",
			SEASONALD->query_move_policy_for_test(
				(["realm_type":"illusion","illusion_state":"active",
					"illusion_id":"S0"]),
				"/gamelib/d/illusion_s1/moon_gate.pike","active")==1,
			"旧周期人物被新配置当作当前人物");
		check("永恒人物不能通过旧书签或传送闯入S1",
			SEASONALD->query_move_policy_for_test(
				(["realm_type":"eternal","illusion_state":""]),
				"/gamelib/d/illusion_s1/moon_gate.pike","active")==3,
			"永恒人物进入S1未失败关闭");
		check("账号世界索引异常时所有移动与共享资产都失败关闭",
			SEASONALD->query_move_policy_for_test(
				(["realm_type":"unavailable","security_blocked":1]),
				"/gamelib/d/congxianzhen/congxianzhenguangchang",
				"active")==4,
			"损坏索引被错误当作普通永恒人物");
		mapping storage = ACCOUNT_STORAGED->query_storage(child);
		check("S1人物不能导入共享仓库、共享玉石或共享宠物",
			!(int)storage["ok"] && ACCOUNT_WALLETD->query_balance(child)==0 &&
			SPIRIT_COMPANIOND->query_pet_battle_source(child)=="personal",
			sprintf("storage=%O wallet=%d source=%s",storage,
				ACCOUNT_WALLETD->query_balance(child),
				SPIRIT_COMPANIOND->query_pet_battle_source(child)));

		mapping progress = SEASONALD->query_player_progress(child);
		check("三路线与七章目标在满条件时按顺序可领取",
			(int)progress["ok"] &&
			sizeof((array)progress["chapters"])==7 &&
			(int)progress["chapters"][0]["ready"] &&
			(string)progress["path"]=="hunter" &&
			(int)progress["route_mark_count"]==3 &&
			SEASONALD->query_route_final_ready_for_test(
				(["path":"pioneer","route_marks":([
					"mirror_moon":1,"hidden_core":1,"returning_mark":1,
				])]))==1 &&
			SEASONALD->query_route_final_ready_for_test(
				(["path":"hunter","route_marks":([
					"broken_star":1,"moon_guard":1,"newmoon_lord":1,
				])]))==1 &&
			SEASONALD->query_route_final_ready_for_test(
				(["path":"companion","team_kills":50]))==1 &&
			SEASONALD->query_route_final_ready_for_test(
				(["path":"pioneer","route_marks":([
					"fake_a":1,"fake_b":1,"fake_c":1,
				])]))==0,
			sprintf("progress=%O",progress));

		int claims_ok = 1;
		for(int chapter=1;chapter<=7;chapter++){
			mapping claim = SEASONALD->claim_chapter_reward_for_test(
				child,chapter);
			if(!(int)claim["ok"] || (int)claim["already"])
				claims_ok = 0;
		}
		int before_duplicate = count_newmoon_items(child);
		mapping duplicate_claim = SEASONALD->claim_chapter_reward_for_test(
			child,7);
		check("七章正好发十件账号绑定套装且重复领取不会克隆",
			claims_ok && before_duplicate==10 &&
			all_newmoon_bound_to(child,account_id) &&
			(int)duplicate_claim["ok"] && (int)duplicate_claim["already"] &&
			count_newmoon_items(child)==10,
			sprintf("claims=%d items=%d duplicate=%O",claims_ok,
				count_newmoon_items(child),duplicate_claim));

		object receipt_hash = Crypto.SHA256();
		receipt_hash->update("S1-test-receipt");
		string receipt = lower_case(String.string2hex(
			receipt_hash->digest()));
		mapping settled = ACCOUNT_CHARACTERD->settle_illusion_character(
			child_id,"S1",receipt);
		mapping settled_again = ACCOUNT_CHARACTERD->settle_illusion_character(
			child_id,"S1",receipt);
		mapping wrong_receipt = ACCOUNT_CHARACTERD->settle_illusion_character(
			child_id,"S1","b"*64);
		child->save_with_result();
		destruct(child);
		child = 0;
		restored = clone(GAMELIB_USER);
		restored->set_name(child_id);
		restored->set_project("gamelib");
		int restored_ok = restored->restore();
		mapping returned_realm = ACCOUNT_CHARACTERD->query_character_realm(
			child_id);
		check("回归只切换账号索引，同一原档案与十件装备完整保留",
			(int)settled["ok"] && !(int)settled["already"] &&
			(int)settled_again["ok"] && (int)settled_again["already"] &&
			!(int)wrong_receipt["ok"] &&
			restored_ok && count_newmoon_items(restored)==10 &&
			(string)returned_realm["realm_type"]=="eternal" &&
			(string)returned_realm["illusion_state"]=="returned" &&
			SEASONALD->query_character_group(child_id)=="",
			sprintf("settled=%O wrong=%O returned=%O items=%d",settled,
				wrong_receipt,
				returned_realm,count_newmoon_items(restored)));
	};
	if(err)
		check("S1完整测试没有运行异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(root) destruct(root);
	if(child) destruct(child);
	if(restored) destruct(restored);
	array(string) known = ACCOUNT_CHARACTERD->query_character_ids(account_id);
	foreach(known,string character_id)
		if(search(character_id,"testunitillusion")!=-1 &&
		   search(cleanup_ids,character_id)==-1)
			cleanup_ids += ({character_id});
	ACCOUNT_STORAGED->remove_test_storage(account_id);
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	foreach(cleanup_ids,string character_id)
		cleanup_player(character_id);
	werror("新月幻境·S1：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
