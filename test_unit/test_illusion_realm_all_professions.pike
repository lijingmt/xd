#!/usr/bin/env pike
/** S1 十二职业从零建角、完成七章、领取穿戴十件套并安全回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results = (["total":0,"passed":0,"failed":0]);

array(mapping(string:string)) professions = ({
	(["race":"human","profession":"jianxian","name":"剑仙"]),
	(["race":"human","profession":"yushi","name":"羽士"]),
	(["race":"human","profession":"zhuxian","name":"诛仙"]),
	(["race":"monst","profession":"kuangyao","name":"狂妖"]),
	(["race":"monst","profession":"wuyao","name":"巫妖"]),
	(["race":"monst","profession":"yinggui","name":"影鬼"]),
	(["race":"third","profession":"fangshi","name":"方士"]),
	(["race":"third","profession":"zhenyue","name":"镇越"]),
	(["race":"third","profession":"tianxiang","name":"天象"]),
	(["race":"third","profession":"lingyi","name":"灵医"]),
	(["race":"third","profession":"wuxiang","name":"无相"]),
	(["race":"third","profession":"taiji","name":"太极"]),
});

array(string) routes = ({"pioneer","hunter","companion"});

array(string) visit_rooms = ({
	"/gamelib/d/illusion_s1/mirror_lake.pike",
	"/gamelib/d/illusion_s1/hidden_crater.pike",
	"/gamelib/d/illusion_s1/newmoon_altar.pike",
	"/gamelib/d/illusion_s1/silver_path.pike",
	"/gamelib/d/illusion_s1/fog_forest.pike",
	"/gamelib/d/illusion_s1/broken_observatory.pike",
	"/gamelib/d/illusion_s1/echo_ruins.pike",
	"/gamelib/d/illusion_s1/star_bridge.pike",
	"/gamelib/d/illusion_s1/abyss_garden.pike",
	"/gamelib/d/illusion_s1/moon_palace.pike",
});

array(string) hunter_bosses = ({
	"star_keeper","moon_general","newmoon_lord",
});

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

void cleanup_account(string account_id,array(string) character_ids)
{
	ACCOUNT_STORAGED->remove_test_storage(account_id);
	ACCOUNT_WALLETD->remove_test_wallet(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	foreach(character_ids,string character_id)
		cleanup_player(character_id);
	cleanup_player(account_id);
}

object create_account_root(string account_id)
{
	object player = clone(GAMELIB_USER);
	player->set_name(account_id);
	player->set_password("testunit88");
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn = "S1十二职业测试账号";
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->save_with_result();
	return player;
}

array(object) query_newmoon_items(object player)
{
	array(object) items = ({});
	foreach(all_inventory(player),object item)
		if(item && functionp(item->query_newmoon_collection_id) &&
		   (string)item->query_newmoon_collection_id()=="newmoon")
			items += ({item});
	return items;
}

int count_equipped_newmoon_items(object player)
{
	int count;
	foreach(query_newmoon_items(player),object item)
		if(item->equiped)
			count++;
	return count;
}

int validate_newmoon_items(object player,string account_id,
	string profession_id)
{
	array(object) items = query_newmoon_items(player);
	multiset(string) slots = (<>);
	if(sizeof(items)!=10)
		return 0;
	foreach(items,object item){
		if(!functionp(item->query_newmoon_account_bind_owner) ||
		   (string)item->query_newmoon_account_bind_owner()!=account_id ||
		   !functionp(item->query_newmoon_resonance_profession) ||
		   (string)item->query_newmoon_resonance_profession()!=profession_id ||
		   !item->query_item_kind() || slots[(string)item->query_item_kind()])
			return 0;
		slots[(string)item->query_item_kind()] = 1;
	}
	return sizeof(slots)==10;
}

int move_for_test(object player,string room_path)
{
	object room;
	int moved;
	mixed err = catch{ room=(object)(ROOT+room_path); };
	if(err || !room)
		return 0;
	player["/tmp/illusion_move_bypass"] = 1;
	err = catch{ moved=player->move(room); };
	player->m_delete_foruser("/tmp/illusion_move_bypass");
	return !err && moved && environment(player)==room;
}

int bootstrap_character(object player,string race_id,string profession_id)
{
	object login_room = (object)(ROOT+"/gamelib/d/init");
	object|zero original_player = this_player();
	int result;
	mixed err = catch{
		set_this_player(player);
		result = login_room->choice_profe(race_id+"/"+profession_id);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	return !err && result &&
		(string)player->query_raceId()==race_id &&
		(string)player->query_profeId()==profession_id;
}

void remove_equipped_items(object player)
{
	array(object) equipped = ({});
	foreach(values(player->query_equip()),mixed candidate)
		if(objectp(candidate) && search(equipped,(object)candidate)==-1)
			equipped += ({(object)candidate});
	foreach(equipped,object item){
		string type = (string)item->query_item_type();
		if(type=="weapon" || type=="single_weapon" || type=="double_weapon")
			player->unwield(item);
		else
			player->unwear(item);
	}
}

mapping(string:mixed) equip_full_set(object player)
{
	object auto_equip = (object)(ROOT+"/gamelib/cmds/auto_equip.pike");
	remove_equipped_items(player);
	return auto_equip->auto_equip_player(player,1);
}

mapping(string:mixed) record_task_progress(object player,string route)
{
	int room_index;
	object normal_npc = clone(ROOT+
		"/gamelib/clone/npc/illusion_s1/moon_wisp.pike");
	mapping result = (["ok":1,"claims":0]);
	mapping progress = SEASONALD->query_player_progress(player);
	array chapters = (array)progress["chapters"];

	for(int chapter_index=0;chapter_index<sizeof(chapters);chapter_index++){
		mapping chapter = (mapping)chapters[chapter_index];
		player->level = (int)chapter["min_level"];
		player->set_att_by_level();

		progress = SEASONALD->query_player_progress(player);
		while((int)progress["visits"]<(int)chapter["visits"] &&
		   room_index<sizeof(visit_rooms)){
			if(!move_for_test(player,visit_rooms[room_index])){
				result = (["ok":0,"message":"真实S1房间移动失败: "+
					visit_rooms[room_index]]);
				destruct(normal_npc);
				return result;
			}
			if(route=="pioneer")
				SEASONALD->discover_route_secret_for_test(player);
			room_index++;
			progress = SEASONALD->query_player_progress(player);
		}

		mapping raw = player["/plus/illusion_realm/S1"];
		while((int)raw["boss_kills"]<(int)chapter["boss_kills"]){
			int boss_index = min((int)raw["boss_kills"],2);
			object boss = clone(ROOT+
				"/gamelib/clone/npc/illusion_s1/"+
				hunter_bosses[boss_index]+".pike");
			boss->move(environment(player));
			SEASONALD->record_npc_kill(player,boss,
				route=="companion" ? 2 : 1);
			destruct(boss);
			raw = player["/plus/illusion_realm/S1"];
		}

		normal_npc->move(environment(player));
		while((int)raw["kills"]<(int)chapter["kills"]){
			SEASONALD->record_npc_kill(player,normal_npc,
				route=="companion" ? 2 : 1);
			raw = player["/plus/illusion_realm/S1"];
		}

		progress = SEASONALD->query_player_progress(player);
		chapters = (array)progress["chapters"];
		if(!(int)chapters[chapter_index]["ready"]){
			result = (["ok":0,"message":sprintf(
				"第%d章真实目标完成后仍不可领取: %O",
				chapter_index+1,progress)]);
			destruct(normal_npc);
			return result;
		}
		mapping claim = SEASONALD->claim_chapter_reward_for_test(
			player,chapter_index+1);
		if(!(int)claim["ok"] || (int)claim["already"]){
			result = (["ok":0,"message":sprintf(
				"第%d章领取失败: %O",chapter_index+1,claim)]);
			destruct(normal_npc);
			return result;
		}
		result["claims"] = chapter_index+1;
		result["items"] = sizeof(query_newmoon_items(player));
	}
	destruct(normal_npc);
	result["progress"] = SEASONALD->query_player_progress(player);
	return result;
}

void run_profession_journey(int index,mapping(string:string) profession)
{
	string account_id = sprintf("xd99testunitillusion%02d",index+1);
	string profession_id = (string)profession["profession"];
	string race_id = (string)profession["race"];
	string profession_name = (string)profession["name"];
	string route = routes[index%sizeof(routes)];
	array(string) cleanup_ids = ({account_id});
	object|zero root = 0;
	object|zero player = 0;
	object|zero restored = 0;
	mixed err;

	cleanup_account(account_id,cleanup_ids);
	err = catch{
		root = create_account_root(account_id);
		if(profession_id=="wuxiang" || profession_id=="taiji"){
			int donation = profession_id=="taiji" ? 10000 : 3000;
			mapping recharge = ACCOUNT_WALLETD->credit_recharge_once(root,
				donation,"testunit",
				ACCOUNT_WALLETD->new_recharge_request_id());
			check(profession_name+"隐藏职业资格按真实共享捐赠解锁",
				(int)recharge["ok"],sprintf("recharge=%O",recharge));
		}

		mapping entitlement = ACCOUNT_CHARACTERD->grant_illusion_entitlement(
			account_id,"test","a"*64);
		mapping created = SEASONALD->create_illusion_character_for_test(
			account_id,race_id,profession_id,"","","");
		string character_id = mappingp(created["character"]) ?
			(string)created["character"]["id"] : "";
		if(character_id!="")
			cleanup_ids += ({character_id});
		check(profession_name+"从真实账号资格创建S1唯一人物档案",
			(int)entitlement["ok"] && (int)created["ok"] &&
			character_id!="" &&
			(string)created["bootstrap_command"]==
				"choice_profe "+race_id+"/"+profession_id &&
			Stdio.file_size(player_file(character_id))>0,
			sprintf("entitlement=%O created=%O",entitlement,created));

		player = clone(GAMELIB_USER);
		player->set_name(character_id);
		player->set_project("gamelib");
		int empty_restored = player->restore();
		check(profession_name+"新人物从规范1级空档开始且任务套装均为零",
			empty_restored && (int)player->query_level()==1 &&
			(int)SEASONALD->query_player_progress(player)["kills"]==0 &&
			sizeof(query_newmoon_items(player))==0,
			sprintf("restore=%d level=%d items=%d",empty_restored,
				(int)player->query_level(),sizeof(query_newmoon_items(player))));

		int bootstrapped = bootstrap_character(player,race_id,profession_id);
		SEASONALD->prepare_new_character(player);
		int entered = move_for_test(player,
			"/gamelib/d/illusion_s1/moon_gate.pike");
		mapping chosen = SEASONALD->choose_player_path_for_test(player,route);
		check(profession_name+"走真实choice_profe初始化并进入S1路线",
			bootstrapped && entered && (int)chosen["ok"] &&
			(int)player->query_level()==1 &&
			(string)player->last_pos==
				"/gamelib/d/illusion_s1/moon_gate.pike" &&
			(string)player->relife==
				"/gamelib/d/illusion_s1/moon_gate.pike",
			sprintf("bootstrap=%d entered=%d route=%O level=%d last=%s relife=%s",
				bootstrapped,entered,chosen,(int)player->query_level(),
				(string)player->last_pos,(string)player->relife));

		object remote_npc = clone(ROOT+
			"/gamelib/clone/npc/illusion_s1/moon_wisp.pike");
		int before_remote = (int)SEASONALD->query_player_progress(player)["kills"];
		SEASONALD->record_npc_kill(player,remote_npc,1);
		int after_remote = (int)SEASONALD->query_player_progress(player)["kills"];
		destruct(remote_npc);
		check(profession_name+"不同房间怪物不能伪造S1任务击杀",
			before_remote==after_remote,
			sprintf("before=%d after=%d",before_remote,after_remote));

		mapping task = record_task_progress(player,route);
		check(profession_name+"逐级完成三路线之一的全部七章任务",
			(int)task["ok"] && (int)task["claims"]==7 &&
			(int)task["progress"]["kills"]==600 &&
			(int)task["progress"]["boss_kills"]==8 &&
			(int)task["progress"]["visits"]>=10 &&
			(string)task["progress"]["path"]==route,
			sprintf("route=%s task=%O",route,task));
		check(profession_name+"七章准确获得本职业十件账号绑定套装",
			validate_newmoon_items(player,account_id,profession_id),
			sprintf("items=%d",sizeof(query_newmoon_items(player))));

		mapping equipped = equip_full_set(player);
		mapping active_skill = NEWMOON_SET_SKILLD->query_active_set_skill(player);
		check(profession_name+"实际脱下新手装并一键穿上完整十件套",
			count_equipped_newmoon_items(player)==10 &&
			(int)query_newmoon_items(player)[0]->
				query_newmoon_set_piece_count()==10 &&
			(string)active_skill["profession"]==profession_id &&
			(string)active_skill["skill"]!="",
			sprintf("equipped=%O count=%d active=%O",equipped,
				count_equipped_newmoon_items(player),active_skill));

		int saved = player->save_with_result();
		destruct(player);
		player = 0;
		restored = clone(GAMELIB_USER);
		restored->set_name(character_id);
		restored->set_project("gamelib");
		int restored_ok = restored->restore();
		mapping restored_skill = NEWMOON_SET_SKILLD->
			query_active_set_skill(restored);
		check(profession_name+"重启式存档重载后十件穿戴与套装技不丢失",
			saved && restored_ok &&
			count_equipped_newmoon_items(restored)==10 &&
			(string)restored_skill["profession"]==profession_id,
			sprintf("saved=%d restored=%d equipped=%d skill=%O",saved,
				restored_ok,count_equipped_newmoon_items(restored),
				restored_skill));

		mapping settled = SEASONALD->settle_player_for_test(restored);
		mapping returned_realm = ACCOUNT_CHARACTERD->
			query_character_realm(character_id);
		int returned_saved = restored->save_with_result();
		destruct(restored);
		restored = 0;
		player = clone(GAMELIB_USER);
		player->set_name(character_id);
		player->set_project("gamelib");
		int returned_restored = player->restore();
		check(profession_name+"S1结算回永恒服仍使用原档并保留穿戴套装",
			(int)settled["ok"] && !(int)settled["already"] &&
			(string)returned_realm["realm_type"]=="eternal" &&
			(string)returned_realm["illusion_state"]=="returned" &&
			returned_saved && returned_restored &&
			count_equipped_newmoon_items(player)==10 &&
			validate_newmoon_items(player,account_id,profession_id),
			sprintf("settled=%O realm=%O saved=%d restored=%d equipped=%d",
				settled,returned_realm,returned_saved,returned_restored,
				count_equipped_newmoon_items(player)));
	};
	if(err)
		check(profession_name+"端到端旅程没有运行异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	if(root)
		destruct(root);
	if(player)
		destruct(player);
	if(restored)
		destruct(restored);
	cleanup_account(account_id,cleanup_ids);
}

int main()
{
	werror("\n========== S1十二职业从零到十件套端到端测试 ==========\n");
	object unauthorized = clone(GAMELIB_USER);
	unauthorized->set_name("xd99testunitother");
	mapping denied_create = SEASONALD->create_illusion_character_for_test(
		"xd99testunitother","human","jianxian","","","");
	mapping denied_route = SEASONALD->choose_player_path_for_test(
		unauthorized,"pioneer");
	mapping denied_secret = SEASONALD->discover_route_secret_for_test(
		unauthorized);
	mapping denied_claim = SEASONALD->claim_chapter_reward_for_test(
		unauthorized,1);
	mapping denied_settle = SEASONALD->settle_player_for_test(unauthorized);
	check("测试专用建角、路线、奖励与结算入口对普通账号全部失败关闭",
		!(int)denied_create["ok"] && !(int)denied_route["ok"] &&
		!(int)denied_secret["ok"] && !(int)denied_claim["ok"] &&
		!(int)denied_settle["ok"],
		sprintf("create=%O route=%O secret=%O claim=%O settle=%O",
			denied_create,denied_route,denied_secret,denied_claim,
			denied_settle));
	destruct(unauthorized);
	for(int index=0;index<sizeof(professions);index++)
		run_profession_journey(index,professions[index]);
	check("十二职业三条路线均被四个职业完整覆盖",
		sizeof(professions)==12 && sizeof(routes)==3,
		"职业或路线矩阵数量错误");
	werror("S1十二职业端到端：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
