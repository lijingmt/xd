#!/usr/bin/env pike
/** S1 十二职业从零建角、完成八十一章、领取穿戴十件套并安全回归。 */

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
	"/gamelib/d/illusion_s1/moon_gate.pike",
	"/gamelib/d/illusion_s1/nanzhan_mortal_city.pike",
	"/gamelib/d/illusion_s1/nanzhan_life_death_temple.pike",
	"/gamelib/d/illusion_s1/fog_oath_camp.pike",
	"/gamelib/d/illusion_s1/xiniu_scripture_market.pike",
	"/gamelib/d/illusion_s1/xiniu_empty_temple.pike",
	"/gamelib/d/illusion_s1/mirror_depths.pike",
	"/gamelib/d/illusion_s1/beiju_longlife_waste.pike",
	"/gamelib/d/illusion_s1/beiju_broken_oath.pike",
	"/gamelib/d/illusion_s1/beiju_frozen_palace.pike",
	"/gamelib/d/illusion_s1/frozen_judgment_hall.pike",
	"/gamelib/d/illusion_s1/dongsheng_morning_port.pike",
	"/gamelib/d/illusion_s1/dongsheng_fusang_altar.pike",
	"/gamelib/d/illusion_s1/moon_immortality_furnace.pike",
	"/gamelib/d/illusion_s1/true_name_hall.pike",
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
	"/gamelib/d/illusion_s1/moon_dew_field.pike",
	"/gamelib/d/illusion_s1/silver_reed_bank.pike",
	"/gamelib/d/illusion_s1/starlight_slope.pike",
	"/gamelib/d/illusion_s1/mist_bamboo_glen.pike",
	"/gamelib/d/illusion_s1/cloud_pine_hollow.pike",
	"/gamelib/d/illusion_s1/moonshadow_wood.pike",
	"/gamelib/d/illusion_s1/mirror_sandbar.pike",
	"/gamelib/d/illusion_s1/glasswater_bank.pike",
	"/gamelib/d/illusion_s1/moonwave_shoal.pike",
	"/gamelib/d/illusion_s1/broken_star_court.pike",
	"/gamelib/d/illusion_s1/astral_stonewood.pike",
	"/gamelib/d/illusion_s1/observatory_outfield.pike",
	"/gamelib/d/illusion_s1/echo_battlement.pike",
	"/gamelib/d/illusion_s1/old_city_square.pike",
	"/gamelib/d/illusion_s1/stardust_lane.pike",
	"/gamelib/d/illusion_s1/abyss_flower_sea.pike",
	"/gamelib/d/illusion_s1/deepmoon_valley.pike",
	"/gamelib/d/illusion_s1/starfall_garden.pike",
});

array(string) hunter_bosses = ({
	"star_keeper","moon_general","eclipse_priest",
});

mapping(string:mapping(string:mixed)) story_events = ([]);

int validate_s1_training_levels()
{
	mapping(string:int) expected = ([
		"moon_wisp":1,"fog_wolf":10,"mirror_spider":20,
		"ruin_guard":30,"star_wraith":40,"abyss_beast":50,
	]);
	foreach(indices(expected),string filename){
		object|zero npc = 0;
		mixed err = catch{ npc=clone(ROOT+
			"/gamelib/clone/npc/illusion_s1/"+filename+".pike"); };
		if(err || !npc || (int)npc->query_level()!=(int)expected[filename]){
			if(npc)
				destruct(npc);
			return 0;
		}
		destruct(npc);
	}
	return 1;
}

int load_story_events()
{
	string source = Stdio.read_file(ROOT+
		"/gamelib/etc/illusion_realm.json") || "";
	mixed decoded;
	mixed err = catch{ decoded=Standards.JSON.decode(source); };
	if(err || !mappingp(decoded) || !arrayp(decoded["story_events"]))
		return 0;
	int locations_complete = 1;
	int boss_levels_match = 1;
	int story_level_cap = (int)decoded["story_level_cap"];
	foreach((array)decoded["story_events"],mapping event){
		story_events[(string)event["id"]] = event;
		if(sizeof((string)event["location"])<2)
			locations_complete = 0;
		if((string)event["kind"]=="boss"){
			object|zero boss = 0;
			mixed boss_error = catch{ boss=clone(ROOT+(string)event["path"]); };
			int expected_level = min(story_level_cap,(int)event["chapter"]);
			if(boss_error || !boss || (int)event["level"]!=expected_level ||
			   (int)boss->query_level()!=expected_level)
				boss_levels_match = 0;
			if(boss)
				destruct(boss);
		}
	}
	return story_level_cap==69 && sizeof(story_events)==25 &&
		locations_complete && boss_levels_match;
}

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

void cleanup_ranking_snapshot(string userid)
{
	string directory;
	string path;
	if(!userid || search(userid,"testunitillusion")==-1)
		return;
	directory = DATA_ROOT+"illusion_realm/rankings/S1";
	path = directory+"/"+userid+".json";
	rm(path);
	foreach(get_dir(directory) || ({}),string filename)
		if(has_prefix(filename,userid+".json.") &&
		   has_suffix(filename,".tmp"))
			rm(directory+"/"+filename);
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
	foreach(character_ids,string character_id){
		cleanup_ranking_snapshot(character_id);
		cleanup_player(character_id);
	}
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

array(object) query_illusion_quest_items(object player)
{
	array(object) items = ({});
	foreach(all_inventory(player),object item)
		if(item && functionp(item->query_illusion_quest_item_id))
			items += ({item});
	return items;
}

int validate_illusion_quest_items(object player,string account_id)
{
	mapping(string:int) expected = ([
		"mortal_lifespan_thread":1,
		"fog_oath_leaf":1,
		"nameless_bone_shard":1,
		"mirror_heart_shard":1,
		"beiju_memory_crystal":1,
		"snow_verdict_seal":1,
		"dawn_flame_seed":1,
		"moon_furnace_life_rune":1,
		"human_world_true_name":1,
	]);
	mapping(string:int) counts = ([]);
	array(object) items = query_illusion_quest_items(player);
	if(sizeof(items)!=9)
		return 0;
	foreach(items,object item){
		string item_id = (string)item->query_illusion_quest_item_id();
		if(!has_index(expected,item_id) ||
		   !functionp(item->query_account_bind_owner) ||
		   (string)item->query_account_bind_owner()!=account_id ||
		   !functionp(item->query_bind_account_on_pickup) ||
		   !(int)item->query_bind_account_on_pickup() ||
		   item->query_item_canDrop()!=0 ||
		   item->query_item_canTrade()!=0 ||
		   item->query_item_canSend()!=0 ||
		   item->query_item_canStorage()!=0 ||
		   item->query_item_task()!=1 || item->query_item_save()!=1)
			return 0;
		counts[item_id] = (int)counts[item_id]+1;
	}
	return sizeof(counts)==9 && equal(counts,expected);
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

/** Every profession must be able to win its first real S1 quick battle. */
mapping(string:mixed) run_first_s1_quick_battle(object player)
{
	object|zero original_player = this_player();
	object|zero target = 0;
	object|zero battle_room = 0;
	object command = (object)(ROOT+
		"/lowlib/wapmud2/cmds/kill_quick.pike");
	string response = "";
	int exp_before = (int)player->query_exp();
	int kills_before = (int)SEASONALD->query_player_progress(player)["kills"];
	int exp_after;
	int kills_after;
	int life_after;
	int command_result;
	int target_present;
	int room_peaceful;
	int target_life_before;
	int target_life_after = -1;
	int target_attack;
	int target_defense;
	int player_attack;
	int player_defense;
	mixed err = catch{
		battle_room = clone(ROOT+
			"/gamelib/d/illusion_s1/moon_dew_field.pike");
		player["/tmp/illusion_move_bypass"] = 1;
		player->move(battle_room);
		player->m_delete_foruser("/tmp/illusion_move_bypass");
		target = clone(ROOT+
			"/gamelib/clone/npc/illusion_s1/moon_wisp.pike");
		target->set_name("__testunit_s1_first_wisp__");
		target->move(environment(player));
		player->_clean_fight();
		player->set_life(player->query_life_max());
		player->set_mofa(player->query_mofa_max());
		player->set_jingli(100);
		player->m_delete_foruser("/tmp/qkill");
		target_present = present(target->query_name(),battle_room,0,player)==
			target;
		room_peaceful = battle_room->is("peaceful");
		target_life_before = (int)target->get_cur_life();
		target_attack = (int)target->query_base_damage();
		target_defense = (int)target->query_defend_power();
		player_attack = (int)player->query_base_damage()+
			(int)player->query_equip_damage("base_attack_main")+
			(int)player->query_equip_damage("base_attack_other");
		player_defense = (int)player->query_defend_power();
		set_this_player(player);
		command_result = command->main(target->query_name()+" 0");
		mapping output = player->query_spliter();
		response = mappingp(output) ? (string)(output["text"] || "") : "";
		exp_after = (int)player->query_exp();
		kills_after = (int)SEASONALD->query_player_progress(player)["kills"];
		life_after = (int)player->get_cur_life();
		if(target)
			target_life_after = (int)target->get_cur_life();
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	move_for_test(player,"/gamelib/d/illusion_s1/moon_dew_field.pike");
	if(battle_room){
		foreach(all_inventory(battle_room),object item)
			if(item) destruct(item);
		destruct(battle_room);
	}
	if(err)
		return (["ok":0,"error":describe_error(err)+" "+
			describe_backtrace(err)]);
	// TestUnit角色不是在线连接，NPC死亡后的find_player归属查询不会
	// 发经验；命令完整跑到目标析构且人物存活，才代表真实战斗胜利。
	// 任务计数及经验奖励入口由同文件后续十二职业旅程分别验证。
	return ([
		"ok":command_result==1 && target_present && !room_peaceful &&
			life_after>0 && target_life_after==-1,
		"response":response,
		"command_result":command_result,
		"target_present":target_present,
		"room_peaceful":room_peaceful,
		"life":life_after,
		"target_life_before":target_life_before,
		"target_life_after":target_life_after,
		"target_attack":target_attack,
		"target_defense":target_defense,
		"player_attack":player_attack,
		"player_defense":player_defense,
		"exp_before":exp_before,
		"exp_after":exp_after,
		"kills_before":kills_before,
		"kills_after":kills_after,
	]);
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

/**
 * Run one bounded, representative player-life loop through the real command
 * and daemon entry points.  The twelve-profession matrix below remains the
 * exhaustive progression check; doing this once keeps every restart fast
 * while guarding the parts that chapter counters alone cannot exercise.
 */
mapping(string:mixed) run_representative_survival_loop(object player)
{
	object|zero original_player = this_player();
	object|zero medicine = 0;
	object|zero enemy = 0;
	mapping result = (["ok":0]);
	mixed err = catch{
		mapping chosen = SPIRIT_COMPANIOND->choose_spirit_companion(
			player,"qingyuanli");
		mapping carried = SPIRIT_COMPANIOND->set_pet_battle_source(
			player,"personal");
		mapping interacted = SPIRIT_COMPANIOND->
			interact_spirit_companion(player);

		int moved = move_for_test(player,
			"/gamelib/d/illusion_s1/moon_dew_field.pike");
		set_this_player(player);
		player["/plus/autofight_smart_route"] = 1;
		AUTOFIGHTD->initialize_player(player);
		AUTOFIGHTD->start_autofight(player);
		((object)(ROOT+"/lowlib/wapmud2/cmds/flushview.pike"))->main(0);
		enemy = player->query_enemy();
		mapping route = AUTOFIGHTD->query_training_route(player);
		SPIRIT_COMPANIOND->reset_spirit_companion_combat_state(player);
		mapping assisted = enemy ? SPIRIT_COMPANIOND->
			perform_spirit_companion_combat_assist(player,enemy) : ([]);
		int fighting = player->query_in_combat() && enemy &&
			enemy->is("npc") && environment(enemy)==environment(player);
		AUTOFIGHTD->stop_autofight(player);
		player->_clean_fight();
		if(enemy)
			enemy->_clean_fight();

		medicine = clone(ROOT+
			"/gamelib/clone/item/food/xinshouhongyao");
		medicine->move(player);
		player->set_life(1);
		int eaten = medicine->eat();
		int life_after = player->query_life();
		mapping equipped = ((object)(ROOT+
			"/gamelib/cmds/auto_equip.pike"))->
			auto_equip_player(player,1);
		mapping inventory = player->query_inventory_browser_snapshot(
			"equipment","");
		mapping pet_state = SPIRIT_COMPANIOND->
			query_spirit_companion_state(player);

		result = ([
			"ok":(int)chosen["ok"] && (int)carried["ok"] &&
				(int)interacted["ok"] && moved && fighting &&
				(string)route["path"]=="illusion_s1/moon_dew_field" &&
				sizeof((array)route["paths"])==3 &&
				(int)route["total_capacity"]>=50 &&
				(int)route["disable_overflow"]==1 &&
				(int)assisted["ok"] && eaten==1 && life_after>1 &&
				life_after<=player->query_life_max() &&
				(int)inventory["matched_physical"]>=4 &&
				SPIRIT_COMPANIOND->query_pet_battle_source(player)==
					"personal" &&
				sizeof((array)pet_state["pets"])==1,
			"chosen":chosen,"carried":carried,
			"interacted":interacted,"route":route,
			"fighting":fighting,"assisted":assisted,
			"eaten":eaten,"life_after":life_after,
			"equipped":equipped,
			"inventory_count":inventory["matched_physical"],
		]);
	};
	AUTOFIGHTD->stop_autofight(player);
	if(player->query_in_combat())
		player->_clean_fight();
	if(enemy && enemy->query_in_combat())
		enemy->_clean_fight();
	if(medicine && environment(medicine))
		destruct(medicine);
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(err)
		return (["ok":0,"error":describe_error(err)+" "+
			describe_backtrace(err)]);
	return result;
}

/** 复现高等级人物击杀低等级剧情首领时经验为零的线上任务故障。 */
mapping(string:mixed) run_zero_exp_story_boss_regression(object player)
{
	mapping original_progress = copy_value(
		(mapping)player["/plus/illusion_realm/S1"]);
	mapping claims = ([]);
	mapping visited = ([]);
	object|zero boss = 0;
	int original_level = (int)player->query_level();
	int zero_exp;
	mapping progress;
	mapping chapter;
	mapping ordinary_route;
	mapping ordinary_window;
	mapping scoped_start;
	mapping scoped_route;
	object|zero ordinary_target = 0;
	object|zero extra_hunt = 0;
	mapping final_view;
	int ordinary_route_valid;
	int ordinary_progress_valid;
	int scoped_route_valid;
	int scoped_stopped;
	int scoped_gate_primed;
	int scoped_returned;
	int scoped_combat_cleared;
	int scoped_final_view;
	int restored;
	for(int chapter_number=1;chapter_number<=8;chapter_number++)
		claims["S1-C"+(string)chapter_number] = time();
	foreach(visit_rooms[..3],string room_path)
		visited[room_path] = 1;
	player["/plus/illusion_realm/S1"] = ([
		"version":1,"joined_at":time(),"kills":82,"boss_kills":0,
		"team_kills":0,"visited":visited,
		"active_days":(["testunit":time()]),"story_events":([]),
		"path":"pioneer","route_marks":([]),"claims":claims,
		"chapter_counter_version":2,"chapter_counter_id":"S1-C9",
		"chapter_kills":0,"chapter_boss_kills":0,
		"chapter_visit_rooms":([]),
	]);
	player->level = 69;
	player->set_att_by_level();
	move_for_test(player,
		"/gamelib/d/illusion_s1/moon_dew_field.pike");
	// 真实回归：人物已经69级，但第九章仍要求1级逐光月灵。普通挂机
	// 必须优先当前章节而非把人物送去50级练级区，且不能达标自停。
	object|zero ordinary_hunt = clone(ROOT+
		"/gamelib/clone/npc/illusion_s1/moon_wisp.pike");
	ordinary_hunt->move(environment(player));
	AUTOFIGHTD->start_autofight(player);
	ordinary_route = AUTOFIGHTD->query_training_route(player);
	ordinary_window = AUTOFIGHTD->query_target_level_window(player);
	ordinary_target = AUTOFIGHTD->query_target(player);
	ordinary_route_valid =
		(string)ordinary_route["path"]==
			"illusion_s1/moon_dew_field" &&
		(int)ordinary_route["chapter_target"]==1 &&
		(int)ordinary_route["level"]==1 &&
		(int)ordinary_window["minimum"]==1 &&
		(int)ordinary_window["maximum"]==1 &&
		ordinary_target &&
		(string)ordinary_target->query_name_cn()=="逐光月灵";
	ordinary_hunt->record_eligible_kill_progress(player,1);
	progress = SEASONALD->query_player_progress(player);
	chapter = (mapping)((array)progress["chapters"])[8];
	ordinary_progress_valid =
		(int)chapter["chapter_kills_done"]==1 &&
		(string)player->query_autofight()=="enable" &&
		!player["/tmp/illusion_chapter_autofight"];
	AUTOFIGHTD->stop_autofight(player);
	destruct(ordinary_hunt);
	ordinary_hunt = 0;

	// 章节专用挂机与普通挂机共用同一目标路线，但内部续跑必须保留
	// 限章标记；第9只确认死亡后精准停止，前8只不能提前停止。
	scoped_start = SEASONALD->start_chapter_hunt_autofight_for_test(player);
	scoped_route = AUTOFIGHTD->query_training_route(player);
	scoped_route_valid = (int)scoped_start["ok"] &&
		(string)scoped_route["path"]=="illusion_s1/moon_dew_field" &&
		(int)scoped_route["chapter_target"]==1 &&
		mappingp(player["/tmp/illusion_chapter_autofight"]) &&
		(string)player["/tmp/illusion_chapter_autofight"]
			["completion_kind"]=="chapter_kills" &&
		(int)player["/tmp/illusion_chapter_autofight"]
			["target_kills"]==9;
	AUTOFIGHTD->resume_autofight(player);
	if(!mappingp(player["/tmp/illusion_chapter_autofight"]))
		scoped_route_valid = 0;
	progress = SEASONALD->query_player_progress(player);
	chapter = (mapping)((array)progress["chapters"])[8];
	scoped_gate_primed = (int)chapter["quest_item_ready"] ||
		SEASONALD->prime_current_quest_item_pity_for_test(player);
	for(int count=1;count<9;count++){
		object hunt = clone(ROOT+
			"/gamelib/clone/npc/illusion_s1/moon_wisp.pike");
		hunt->move(environment(player));
		// 线上复现：最后一只任务怪结算时，群攻仇恨表仍有另一只
		// 同房间任务怪。限章挂机必须安全脱战并发布最终画面。
		if(count==8){
			extra_hunt = clone(ROOT+
				"/gamelib/clone/npc/illusion_s1/moon_wisp.pike");
			extra_hunt->move(environment(player));
			player->_fight(extra_hunt);
			extra_hunt->_fight(player);
		}
		hunt->record_eligible_kill_progress(player,1);
		destruct(hunt);
		if(count<8 && ((string)player->query_autofight()!="enable" ||
		   !mappingp(player["/tmp/illusion_chapter_autofight"])))
			scoped_route_valid = 0;
	}
	scoped_stopped = (string)player->query_autofight()=="disable" &&
		!player["/tmp/illusion_chapter_autofight"];
	scoped_combat_cleared = !player->query_in_combat() && extra_hunt &&
		!extra_hunt->query_in_combat();
	final_view = AUTOFIGHTD->query_server_autofight_view(player);
	scoped_final_view = !(int)final_view["active"] &&
		search((string)final_view["output"],"章节狩猎完成")!=-1 &&
		search((string)final_view["output"],"illusion_realm")!=-1;
	scoped_returned = scoped_stopped &&
		SEASONALD->complete_chapter_task_return_for_test(player) &&
		(string)player["/tmp/illusion_chapter_last_return"]=="S1-C9" &&
		!player["/tmp/illusion_chapter_return_pending"];
	// 第九章先完成普通狩猎和卷末信物，再挑战剧情首领。仍用高等级
	// 人物验证合法零经验不会吞掉死亡归属和剧情任务记账。
	int boss_room_ready = move_for_test(player,
		"/gamelib/d/illusion_s1/nanzhan_life_death_temple.pike");
	if(boss_room_ready){
		boss = clone(ROOT+
			"/gamelib/clone/npc/illusion_s1/life_collector.pike");
		boss->move(environment(player));
		zero_exp = boss->grant_kill_experience(player,0);
		boss->record_eligible_kill_progress(player,1);
	}
	move_for_test(player,
		"/gamelib/d/illusion_s1/starlight_slope.pike");
	progress = SEASONALD->query_player_progress(player);
	chapter = (mapping)((array)progress["chapters"])[8];
	int valid = boss_room_ready && boss && zero_exp==0 &&
		(int)player->query_level()-(int)boss->query_level()>=10 &&
		ordinary_route_valid && ordinary_progress_valid &&
		scoped_route_valid && scoped_gate_primed && scoped_stopped &&
		scoped_combat_cleared && scoped_final_view && scoped_returned &&
		(int)progress["kills"]==92 && (int)progress["boss_kills"]==1 &&
		(int)chapter["chapter_kills_done"]==9 &&
		(int)chapter["chapter_boss_kills_done"]==1 &&
		(int)chapter["story_ready"] && (int)chapter["ready"];
	if(boss)
		destruct(boss);
	boss = 0;
	if(extra_hunt)
		destruct(extra_hunt);
	extra_hunt = 0;
	player["/plus/illusion_realm/S1"] = original_progress;
	player->level = original_level;
	player->set_att_by_level();
	foreach(all_inventory(player),object item)
		if(item && functionp(item->query_illusion_quest_item_id) &&
		   (string)item->query_illusion_quest_item_id()==
			"mortal_lifespan_thread")
			destruct(item);
	restored = player->save_with_result();
	move_for_test(player,"/gamelib/d/illusion_s1/moon_dew_field.pike");
	return (["ok":valid && restored,"zero_exp":zero_exp,
		"progress":progress,"chapter":chapter,"restored":restored,
		"ordinary_route":ordinary_route,
		"ordinary_window":ordinary_window,
		"ordinary_route_valid":ordinary_route_valid,
		"ordinary_progress_valid":ordinary_progress_valid,
		"scoped_start":scoped_start,"scoped_route":scoped_route,
		"scoped_route_valid":scoped_route_valid,
		"scoped_stopped":scoped_stopped,
		"scoped_gate_primed":scoped_gate_primed,
		"scoped_combat_cleared":scoped_combat_cleared,
		"scoped_final_view":scoped_final_view,
		"scoped_returned":scoped_returned]);
}

string hunt_npc_path(string hunt_name)
{
	mapping(string:string) paths = ([
		"逐光月灵":"/gamelib/clone/npc/illusion_s1/moon_wisp.pike",
		"雾纹月狼":"/gamelib/clone/npc/illusion_s1/fog_wolf.pike",
		"镜丝月蛛":"/gamelib/clone/npc/illusion_s1/mirror_spider.pike",
		"折星石卫":"/gamelib/clone/npc/illusion_s1/ruin_guard.pike",
		"古城星魇":"/gamelib/clone/npc/illusion_s1/star_wraith.pike",
		"渊花异兽":"/gamelib/clone/npc/illusion_s1/abyss_beast.pike",
	]);
	return (string)(paths[hunt_name] || "");
}

mapping(string:mixed) record_task_progress(object player,string route)
{
	mapping result = (["ok":1,"claims":0,"event_gates_tested":0,
		"quest_gates_completed":0]);
	mapping progress = SEASONALD->query_player_progress(player);
	array chapters = (array)progress["chapters"];
	int narrative_chapters;
	int narrative_outros;
	foreach(chapters,mapping story_chapter){
		array(string) story_lines = (string)story_chapter["intro"]/"\n";
		array(string) outro_lines = (string)story_chapter["outro"]/"\n";
		int valid_lines = sizeof(story_lines)==5;
		int valid_outro_lines = sizeof(outro_lines)==3;
		foreach(story_lines,string story_line)
			if(sizeof(String.trim_all_whites(story_line))<24)
				valid_lines = 0;
		foreach(outro_lines,string story_line)
			if(sizeof(String.trim_all_whites(story_line))<24)
				valid_outro_lines = 0;
		if(valid_lines)
			narrative_chapters++;
		if(valid_outro_lines)
			narrative_outros++;
	}
	result["narrative_chapters"] = narrative_chapters;
	result["narrative_outros"] = narrative_outros;
	if(!move_for_test(player,
	   "/gamelib/d/illusion_s1/true_name_hall.pike"))
		return (["ok":0,"message":"未来剧情房间移动测试失败"]);
	mapping future_event = SEASONALD->discover_story_event_for_test(player);
	if((int)future_event["ok"])
		return (["ok":0,"message":sprintf(
			"未完成前置章节却提前触发第七十七章事件: %O",
			future_event)]);
	result["future_event_blocked"] = 1;
	progress = SEASONALD->query_player_progress(player);
	result["activity_days_before"] = (int)progress["active_days"];

	// 三条路线先用各自真实动作完成长期里程碑；这些里程碑不会替代
	// 任一章节的独立狩猎、首领或探索目标。
	if(route=="hunter")
		foreach(hunter_bosses,string hunter_boss_name){
			object hunter_boss = clone(ROOT+
				"/gamelib/clone/npc/illusion_s1/"+
				hunter_boss_name+".pike");
			hunter_boss->move(environment(player));
			SEASONALD->record_npc_kill(player,hunter_boss,1);
			destruct(hunter_boss);
		}
	if(route=="pioneer")
		foreach(({"mirror_lake","hidden_crater","newmoon_altar"}),
		   string room_name){
			if(!move_for_test(player,
			   "/gamelib/d/illusion_s1/"+room_name+".pike"))
				return (["ok":0,"message":"寻星路线房间移动失败: "+
					room_name]);
			mapping secret = SEASONALD->discover_route_secret_for_test(player);
			if(!(int)secret["ok"])
				return (["ok":0,"message":sprintf(
					"寻星路线里程碑失败: %O",secret)]);
		}

	for(int chapter_index=0;chapter_index<sizeof(chapters);chapter_index++){
		progress = SEASONALD->query_player_progress(player);
		mapping chapter = (mapping)((array)progress["chapters"])
			[chapter_index];
		if((int)player->query_level()<(int)chapter["min_level"])
			return (["ok":0,"message":sprintf(
				"第%d章开始前等级未由此前章节自然推进: level=%d need=%d",
				chapter_index+1,(int)player->query_level(),
				(int)chapter["min_level"])]);
		if((int)chapter["ready"])
			return (["ok":0,"message":sprintf(
				"第%d章尚未执行本章动作却已经可领取: %O",
				chapter_index+1,chapter)]);
		if(chapter_index==0){
			mapping future_claim = SEASONALD->
				claim_chapter_reward_for_test(player,2);
			if((int)future_claim["ok"])
				return (["ok":0,"message":sprintf(
					"未来章节奖励可被越序领取: %O",future_claim)]);
		}

		int guard;
		while(guard++<2000){
			progress = SEASONALD->query_player_progress(player);
			chapter = (mapping)((array)progress["chapters"])
				[chapter_index];
			string kind = (string)chapter["target_kind"];
			if((int)result["scoped_autofight_started"] &&
			   !(int)result["scoped_autofight_stopped"] && kind!="hunt"){
				if((string)player->query_autofight()=="enable" ||
				   player["/tmp/illusion_chapter_autofight"])
					return (["ok":0,"message":sprintf(
						"第%d章限章挂机达标后没有停止",chapter_index+1)]);
				result["scoped_autofight_stopped"] = 1;
			}
			if((int)result["normal_autofight_started"] &&
			   !(int)result["normal_autofight_preserved"] && kind!="hunt"){
				if((string)player->query_autofight()!="enable" ||
				   player["/tmp/illusion_chapter_autofight"])
					return (["ok":0,"message":sprintf(
						"第%d章普通持续挂机被章节完成误停",
						chapter_index+1)]);
				result["normal_autofight_preserved"] = 1;
				AUTOFIGHTD->stop_autofight(player);
			}
			if((int)chapter["ready"])
				break;
			string target_room = (string)chapter["target_room"];
			if(kind=="story_echo" || kind=="story_boss"){
				string event_id = (string)chapter["story_event"];
				mapping event = story_events[event_id];
				if((int)chapter["quest_item_required"]>0){
					if(!(int)chapter["quest_item_ready"])
						return (["ok":0,"message":sprintf(
							"第%d章在卷末信物完成前提前进入剧情高潮: %O",
							chapter_index+1,chapter)]);
					result["quest_gates_before_story"] =
						(int)result["quest_gates_before_story"]+1;
				}
				if(!mappingp(event) || (int)chapter["story_ready"] ||
				   (string)chapter["story_event_location"]!=
					(string)event["location"] ||
				   target_room!=(kind=="story_echo" ?
					(string)event["path"] : (string)event["room"]))
					return (["ok":0,"message":sprintf(
						"第%d章剧情目标配置或顺序异常: %O event=%O",
						chapter_index+1,chapter,event)]);
				if(kind=="story_boss" &&
				   !(int)result["wrong_story_room_blocked"]){
					int boss_done_before =
						(int)chapter["chapter_boss_kills_done"];
					string wrong_story_room = target_room==
						"/gamelib/d/illusion_s1/moon_gate.pike" ?
						"/gamelib/d/illusion_s1/true_name_hall.pike" :
						"/gamelib/d/illusion_s1/moon_gate.pike";
					if(!move_for_test(player,wrong_story_room))
						return (["ok":0,"message":
							"剧情首领错误房间回归测试移动失败"]);
					object wrong_room_boss = clone(ROOT+
						(string)event["path"]);
					wrong_room_boss->move(environment(player));
					wrong_room_boss->record_eligible_kill_progress(player,1);
					destruct(wrong_room_boss);
					mapping after_wrong_story = SEASONALD->
						query_player_progress(player);
					mapping after_wrong_chapter = (mapping)((array)
						after_wrong_story["chapters"])[chapter_index];
					if((int)after_wrong_chapter["story_ready"] ||
					   (int)after_wrong_chapter[
						"chapter_boss_kills_done"]!=boss_done_before)
						return (["ok":0,"message":sprintf(
							"剧情首领在错误房间仍推进章节: %O",
							after_wrong_chapter)]);
					result["wrong_story_room_blocked"] = 1;
				}
				result["event_gates_tested"] =
					(int)result["event_gates_tested"]+1;
				if(!move_for_test(player,target_room))
					return (["ok":0,"message":"剧情目标房间移动失败: "+
						target_room]);
				if(kind=="story_echo"){
					mapping witnessed = SEASONALD->
						discover_story_event_for_test(player);
					if(!(int)witnessed["ok"] ||
					   (int)witnessed["already"])
						return (["ok":0,"message":sprintf(
							"第%d章故事残响失败: %O",
							chapter_index+1,witnessed)]);
				}
				else{
					object story_boss = clone(ROOT+(string)event["path"]);
					story_boss->move(environment(player));
					story_boss->record_eligible_kill_progress(player,
						route=="companion" ? 2 : 1);
					destruct(story_boss);
				}
				continue;
			}
				if(kind=="hunt"){
					string npc_path = hunt_npc_path(
						(string)chapter["target_name"]);
				if(npc_path=="" || target_room=="" ||
				   target_room!=(string)chapter["hunt_room"] ||
				   !move_for_test(player,target_room))
						return (["ok":0,"message":sprintf(
							"第%d章狩猎目标配置或移动失败: %O",
							chapter_index+1,chapter)]);
					if((string)chapter["story_event"]!="" &&
					   !(int)result["early_story_echo_blocked"]){
						mapping early_echo=story_events[
							(string)chapter["story_event"]];
						if(mappingp(early_echo) &&
						   (string)early_echo["kind"]=="echo"){
							if(!move_for_test(player,(string)early_echo["path"]))
								return (["ok":0,"message":
									"故事残响越序测试移动失败"]);
							mapping early_read=SEASONALD->
								discover_story_event_for_test(player);
							mapping after_early_read=SEASONALD->
								query_player_progress(player);
							mapping early_read_chapter=(mapping)((array)
								after_early_read["chapters"])[chapter_index];
							if((int)early_read["ok"] ||
							   (int)early_read_chapter["story_ready"] ||
							   !move_for_test(player,target_room))
								return (["ok":0,"message":sprintf(
									"未完成本章狩猎仍可越序阅读关键剧情: %O %O",
									early_read,early_read_chapter)]);
							result["early_story_echo_blocked"]=1;
						}
					}
					if((int)chapter["quest_item_required"]>0 &&
				   !(int)chapter["quest_item_ready"] &&
				   !(int)result["quest_gate_early_story_blocked"]){
					mapping early_event=story_events[
						(string)chapter["story_event"]];
					if(mappingp(early_event) &&
					   (string)early_event["kind"]=="boss"){
						int boss_before=(int)chapter[
							"chapter_boss_kills_done"];
						if(!move_for_test(player,(string)early_event["room"]))
							return (["ok":0,"message":
								"卷末首领越序测试移动失败"]);
						object early_boss=clone(ROOT+
							(string)early_event["path"]);
						early_boss->move(environment(player));
						SEASONALD->record_npc_kill(player,early_boss,1);
						destruct(early_boss);
						mapping after_early=SEASONALD->
							query_player_progress(player);
						mapping early_chapter=(mapping)((array)
							after_early["chapters"])[chapter_index];
						if((int)early_chapter["story_ready"] ||
						   (int)early_chapter["chapter_boss_kills_done"]!=
							boss_before || !move_for_test(player,target_room))
							return (["ok":0,"message":sprintf(
								"未完成狩猎/信物仍可越序击杀卷末首领: %O",
								early_chapter)]);
						result["quest_gate_early_story_blocked"]=1;
					}
				}
				if((int)chapter["quest_item_required"]>0 &&
				   !(int)chapter["quest_item_ready"] &&
				   !(int)result["quest_gate_wrong_sources_blocked"]){
					int count_before = (int)chapter["quest_item_count"];
					int pity_before = (int)chapter["quest_item_pity"];
					string wrong_gate_path = npc_path==
						"/gamelib/clone/npc/illusion_s1/moon_wisp.pike" ?
						"/gamelib/clone/npc/illusion_s1/abyss_beast.pike" :
						"/gamelib/clone/npc/illusion_s1/moon_wisp.pike";
					object wrong_gate_npc = clone(ROOT+wrong_gate_path);
					wrong_gate_npc->move(environment(player));
					SEASONALD->record_npc_kill(player,wrong_gate_npc,1);
					destruct(wrong_gate_npc);
					if(!move_for_test(player,
					   "/gamelib/d/illusion_s1/moon_gate.pike"))
						return (["ok":0,"message":
							"剧情道具错误房间测试移动失败"]);
					object misplaced_gate_npc = clone(ROOT+npc_path);
					misplaced_gate_npc->move(environment(player));
					SEASONALD->record_npc_kill(player,misplaced_gate_npc,1);
					destruct(misplaced_gate_npc);
					mapping gate_after = SEASONALD->query_player_progress(player);
					mapping gate_chapter = (mapping)((array)
						gate_after["chapters"])[chapter_index];
					if((int)gate_chapter["quest_item_count"]!=count_before ||
					   (int)gate_chapter["quest_item_pity"]!=pity_before ||
					   !move_for_test(player,target_room))
						return (["ok":0,"message":sprintf(
							"错误怪物或错误房间推进剧情道具保底: %O",
							gate_chapter)]);
					result["quest_gate_wrong_sources_blocked"] = 1;
				}
				if(chapter_index==0 &&
				   !(int)result["wrong_hunt_target_blocked"]){
					int global_before = (int)progress["kills"];
					int hunt_before = (int)chapter["chapter_kills_done"];
					int visits_before =
						(int)chapter["chapter_visits_done"];
					object wrong_npc = clone(ROOT+
						"/gamelib/clone/npc/illusion_s1/abyss_beast.pike");
					wrong_npc->move(environment(player));
					SEASONALD->record_npc_kill(player,wrong_npc,1);
					destruct(wrong_npc);
					if(!move_for_test(player,
					   "/gamelib/d/illusion_s1/moon_gate.pike"))
						return (["ok":0,"message":
							"错误狩猎房间回归测试移动失败"]);
					object misplaced_npc = clone(ROOT+npc_path);
					misplaced_npc->move(environment(player));
					SEASONALD->record_npc_kill(player,misplaced_npc,1);
					destruct(misplaced_npc);
					mapping after_wrong_hunt = SEASONALD->
						query_player_progress(player);
					mapping after_wrong_hunt_chapter = (mapping)((array)
						after_wrong_hunt["chapters"])[chapter_index];
					if((int)after_wrong_hunt["kills"]!=global_before+2 ||
					   (int)after_wrong_hunt_chapter[
						"chapter_kills_done"]!=hunt_before ||
					   (int)after_wrong_hunt_chapter[
						"chapter_visits_done"]!=visits_before ||
					   !move_for_test(player,target_room))
						return (["ok":0,"message":sprintf(
							"错误怪物、错误房间或提前探索仍推进章节: %O",
							after_wrong_hunt_chapter)]);
					result["wrong_hunt_target_blocked"] = 1;
				}
				if(chapter_index==0 &&
				   !(int)result["duplicate_death_callback_blocked"]){
					mapping before_duplicate = SEASONALD->
						query_player_progress(player);
					mapping before_duplicate_chapter = (mapping)((array)
						before_duplicate["chapters"])[chapter_index];
					int global_before = (int)before_duplicate["kills"];
					int hunt_before = (int)before_duplicate_chapter[
						"chapter_kills_done"];
					object duplicate_npc = clone(ROOT+npc_path);
					duplicate_npc->move(environment(player));
					duplicate_npc->record_eligible_kill_progress(player,1);
					duplicate_npc->record_eligible_kill_progress(player,1);
					destruct(duplicate_npc);
					mapping after_duplicate = SEASONALD->
						query_player_progress(player);
					mapping duplicate_chapter = (mapping)((array)
						after_duplicate["chapters"])[chapter_index];
					if((int)after_duplicate["kills"]!=global_before+1 ||
					   (int)duplicate_chapter["chapter_kills_done"]!=
						hunt_before+1)
						return (["ok":0,"message":sprintf(
							"同一NPC死亡回调重复推进章节: before=%d/%d after=%O",
							global_before,hunt_before,after_duplicate)]);
					result["duplicate_death_callback_blocked"] = 1;
				}
				if(chapter_index==0 &&
				   !(int)result["scoped_autofight_started"]){
					mapping started = SEASONALD->
						start_chapter_hunt_autofight_for_test(player);
					if(!(int)started["ok"] ||
					   (string)player->query_autofight()!="enable" ||
					   !mappingp(player[
						"/tmp/illusion_chapter_autofight"]))
						return (["ok":0,"message":sprintf(
							"限章挂机启动失败: %O",started)]);
					result["scoped_autofight_started"] = 1;
				}
				if(chapter_index==1 &&
				   !(int)result["normal_autofight_started"]){
					AUTOFIGHTD->start_autofight(player);
					if((string)player->query_autofight()!="enable" ||
					   player["/tmp/illusion_chapter_autofight"])
						return (["ok":0,"message":
							"普通持续挂机启动后残留限章标记"]);
					result["normal_autofight_started"] = 1;
				}
				if((int)chapter["quest_item_required"]>0 &&
				   !(int)chapter["quest_item_ready"]){
					if(!SEASONALD->prime_current_quest_item_pity_for_test(
					   player))
						return (["ok":0,"message":sprintf(
							"第%d章剧情道具硬保底测试准备失败: %O",
							chapter_index+1,chapter)]);
					result["quest_gate_pities_primed"] =
						(int)result["quest_gate_pities_primed"]+1;
				}
				object hunt_npc = clone(ROOT+npc_path);
				hunt_npc->move(environment(player));
				SEASONALD->record_npc_kill(player,hunt_npc,
					route=="companion" ? 2 : 1);
				destruct(hunt_npc);
				continue;
			}
			if(kind=="boss"){
				if(target_room!=
				   "/gamelib/d/illusion_s1/star_bridge.pike" ||
				   !move_for_test(player,target_room))
					return (["ok":0,"message":sprintf(
						"第%d章首领目标配置或移动失败: %O",
						chapter_index+1,chapter)]);
				object boss = clone(ROOT+
					"/gamelib/clone/npc/illusion_s1/star_keeper.pike");
				boss->move(environment(player));
				SEASONALD->record_npc_kill(player,boss,
					route=="companion" ? 2 : 1);
				destruct(boss);
				continue;
			}
			if(kind=="explore"){
				mapping travel = SEASONALD->travel_to_chapter_target(
					player,chapter_index+1);
				mapping arrived_progress =
					SEASONALD->query_player_progress(player);
				mapping arrived_chapter = (mapping)((array)
					arrived_progress["chapters"])[chapter_index];
				if(target_room=="" || !(int)travel["ok"] ||
				   !MAP_WORKERD->static_room_locations_match(
					file_name(environment(player)),target_room) ||
				   (int)arrived_chapter["chapter_visits_done"]<
					(int)arrived_chapter["chapter_visits"])
					return (["ok":0,"message":sprintf(
						"第%d章章节直达未自动记录真实探索: chapter=%O travel=%O after=%O",
						chapter_index+1,chapter,travel,arrived_chapter)]);
				if(!(int)result["explore_retry_recovered"]){
					mapping raw_progress = (mapping)player[
						"/plus/illusion_realm/S1"];
					raw_progress["chapter_visit_rooms"] = ([]);
					mapping retry = SEASONALD->travel_to_chapter_target(
						player,chapter_index+1);
					mapping retry_progress =
						SEASONALD->query_player_progress(player);
					mapping retry_chapter = (mapping)((array)
						retry_progress["chapters"])[chapter_index];
					if(!(int)retry["ok"] || !(int)retry["already"] ||
					   (int)retry_chapter["chapter_visits_done"]<
						(int)retry_chapter["chapter_visits"])
						return (["ok":0,"message":sprintf(
							"第%d章已在目标房但0/1探索未能自愈: retry=%O after=%O",
							chapter_index+1,retry,retry_chapter)]);
					result["explore_retry_recovered"] = 1;
				}
				continue;
			}
			return (["ok":0,"message":sprintf(
				"第%d章进入不可执行状态 kind=%s chapter=%O",
				chapter_index+1,kind,chapter)]);
		}
		if(guard>=2000)
			return (["ok":0,"message":sprintf(
				"第%d章状态机超过安全步数",chapter_index+1)]);

		progress = SEASONALD->query_player_progress(player);
		chapters = (array)progress["chapters"];
		if(!(int)chapters[chapter_index]["ready"])
			return (["ok":0,"message":sprintf(
				"第%d章真实目标完成后仍不可领取: %O",
				chapter_index+1,progress)]);
		if((int)chapters[chapter_index]["quest_item_required"]>0){
			mapping gate_status = (mapping)chapters[chapter_index];
			if(!(int)gate_status["quest_item_ready"] ||
			   (int)gate_status["quest_item_count"]<
				(int)gate_status["quest_item_required"] ||
			   (int)gate_status["quest_item_pity"]!=0)
				return (["ok":0,"message":sprintf(
					"第%d章剧情道具未满足真实数量或掉落后保底未清零: %O",
					chapter_index+1,gate_status)]);
			result["quest_gates_completed"] =
				(int)result["quest_gates_completed"]+1;
		}
		mapping claim = SEASONALD->claim_chapter_reward_for_test(
			player,chapter_index+1);
		int expected_level = min(69,chapter_index+2);
		if(!(int)claim["ok"] || (int)claim["already"] ||
		   (int)player->query_level()!=expected_level ||
		   !mappingp(claim["growth"]) ||
		   (int)claim["growth"]["after_level"]!=expected_level)
			return (["ok":0,"message":sprintf(
				"第%d章领取或章回悟境失败: level=%d expected=%d claim=%O",
				chapter_index+1,(int)player->query_level(),expected_level,
				claim)]);
		mapping repeat_claim = SEASONALD->claim_chapter_reward_for_test(
			player,chapter_index+1);
		if(!(int)repeat_claim["ok"] || !(int)repeat_claim["already"])
			return (["ok":0,"message":sprintf(
				"第%d章重复领取不幂等: %O",chapter_index+1,
				repeat_claim)]);
		if(chapter_index+1<sizeof(chapters)){
			mapping after_claim = SEASONALD->query_player_progress(player);
			mapping next_chapter = (mapping)((array)
				after_claim["chapters"])[chapter_index+1];
			if((int)next_chapter["chapter_kills_done"]!=0 ||
			   (int)next_chapter["chapter_boss_kills_done"]!=0 ||
			   (int)next_chapter["chapter_visits_done"]!=0 ||
			   (int)next_chapter["ready"])
				return (["ok":0,"message":sprintf(
					"第%d章领取后战绩被错误带入第%d章: %O",
					chapter_index+1,chapter_index+2,next_chapter)]);
		}
		result["claims"] = chapter_index+1;
		result["items"] = sizeof(query_newmoon_items(player));
	}
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
	int quiz_completed;
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
			account_id,"test","a"*64,"S1");
		int slot_jade = YUSHID->give_yushi(root,100);
		mapping slot_purchase = SEASONALD->purchase_character_expansion(
			root,"one");
		mapping created = SEASONALD->create_illusion_character_for_test(
			account_id,race_id,profession_id,"","","");
		string character_id = mappingp(created["character"]) ?
			(string)created["character"]["id"] : "";
		if(character_id!="")
			cleanup_ids += ({character_id});
		check(profession_name+"从真实账号资格创建S1唯一人物档案",
			(int)entitlement["ok"] && slot_jade &&
			(int)slot_purchase["ok"] && (int)created["ok"] &&
			character_id!="" &&
			(string)created["bootstrap_command"]==
				"choice_profe "+race_id+"/"+profession_id &&
			Stdio.file_size(player_file(character_id))>0,
			sprintf("entitlement=%O slot=%O created=%O",entitlement,
				slot_purchase,created));

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
		if(index==0){
			mapping legacy_progress=(mapping)player[
				"/plus/illusion_realm/S1"];
			m_delete(legacy_progress,"content_id");
			mapping legacy_main=SEASONALD->query_player_progress(player);
			mapping legacy_journey=ILLUSION_JOURNEYD->query_journey(player);
			check("S1首批无content_id真实人物可补齐并进入新月回响",
				(int)legacy_main["ok"] && (int)legacy_journey["ok"] &&
				(string)legacy_progress["content_id"]=="S1",
				sprintf("main=%O journey=%O progress=%O",legacy_main,
					legacy_journey,legacy_progress));
			legacy_progress["content_id"]="S2";
			mapping conflict_journey=ILLUSION_JOURNEYD->query_journey(player);
			check("S1真实人物显式冲突内容编号仍失败关闭",
				!(int)conflict_journey["ok"] &&
				(string)legacy_progress["content_id"]=="S2",
				sprintf("conflict=%O",conflict_journey));
			legacy_progress["content_id"]="S1";
		}

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
		if(index==0)
			check("剧情道具万分比边界真实使用1..10000闭区间",
				SEASONALD->query_quest_item_random_drop_for_test(
					player,2000,2000)==1 &&
				SEASONALD->query_quest_item_random_drop_for_test(
					player,2000,2001)==0 &&
				SEASONALD->query_quest_item_random_drop_for_test(
					player,200,200)==1 &&
				SEASONALD->query_quest_item_random_drop_for_test(
					player,200,201)==0,
					"20%与2%临界值必须准确且不能四舍五入");

		mapping first_battle = run_first_s1_quick_battle(player);
		check(profession_name+"一级空档可真实击败S1首只逐光月灵",
			(int)first_battle["ok"],sprintf("battle=%O",first_battle));
		if(index==6)
			player["/plus/newbie_tutorial/step"] = 17;

		if(index==0){
			mapping survival = run_representative_survival_loop(player);
			check("代表人物真实完成挂机开战、灵伴协战、吃药和背包穿装",
				(int)survival["ok"],sprintf("survival=%O",survival));
			mapping zero_exp_boss =
				run_zero_exp_story_boss_regression(player);
			check("高等级零经验击杀南瞻司寿使仍推进第九章并可领取",
				(int)zero_exp_boss["ok"],
				sprintf("regression=%O",zero_exp_boss));
		}

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
		check(profession_name+"逐级完成三路线之一的全部八十一章任务",
			(int)task["ok"] && (int)task["claims"]==81 &&
			(int)task["narrative_chapters"]==81 &&
			(int)task["narrative_outros"]==81 &&
			(int)player->query_level()==69 &&
			(int)task["progress"]["kills"]>=760 &&
			(int)task["progress"]["boss_kills"]>=10 &&
			(int)task["progress"]["visits"]>=36 &&
			(int)task["progress"]["visits"]<=sizeof(visit_rooms) &&
			(int)task["progress"]["active_days"]==
				(int)task["activity_days_before"] &&
			(int)task["progress"]["active_days"]<=1 &&
			(int)task["progress"]["story_event_count"]==25 &&
			(int)task["future_event_blocked"]==1 &&
			(int)task["event_gates_tested"]==25 &&
			(int)task["quest_gates_completed"]==9 &&
				(int)task["quest_gates_before_story"]==9 &&
				(int)task["quest_gate_pities_primed"]==9 &&
				(int)task["quest_gate_early_story_blocked"]==1 &&
				(int)task["quest_gate_wrong_sources_blocked"]==1 &&
				(int)task["early_story_echo_blocked"]==1 &&
				(int)task["wrong_story_room_blocked"]==1 &&
			(int)task["wrong_hunt_target_blocked"]==1 &&
			(int)task["duplicate_death_callback_blocked"]==1 &&
			(int)task["scoped_autofight_started"]==1 &&
			(int)task["scoped_autofight_stopped"]==1 &&
			(int)task["normal_autofight_started"]==1 &&
			(int)task["normal_autofight_preserved"]==1 &&
			(int)task["explore_retry_recovered"]==1 &&
			(string)task["progress"]["path"]==route,
			sprintf("route=%s task=%O",route,task));
		mapping route_ending = SEASONALD->query_story_quiz(player);
		mapping expected_route_titles = ([
			"pioneer":"寻月·微光成卷",
			"hunter":"逐影·刀止于人",
			"companion":"同行·万家有灯",
		]);
		check(profession_name+"完成正史后只看到自己命途的原创终幕",
			(int)route_ending["unlocked"] &&
			mappingp(route_ending["route_epilogue"]) &&
			(string)((mapping)route_ending["route_epilogue"])["title"]==
				(string)expected_route_titles[route] &&
			sizeof(((string)((mapping)route_ending[
				"route_epilogue"])["text"])/"\n")==5,
			sprintf("route=%s ending=%O",route,route_ending));
		if(index==6)
			check("章节升级事务不会越界触发方士新手奖励",
				(int)player["/plus/newbie_tutorial/step"]==17,
				sprintf("tutorial_step=%d",
					(int)player["/plus/newbie_tutorial/step"]));
		check(profession_name+"八十一章准确获得本职业十件账号绑定套装",
			validate_newmoon_items(player,account_id,profession_id),
			sprintf("items=%d",sizeof(query_newmoon_items(player))));
		check(profession_name+"九卷剧情卡点掉落九件账号绑定任务道具",
			validate_illusion_quest_items(player,account_id),
			sprintf("quest_items=%O",query_illusion_quest_items(player)));
		if(index==0){
			mapping story_config = Standards.JSON.decode(Stdio.read_file(ROOT+
				"/gamelib/etc/illusion_s1_story.json"));
			mapping quiz_started = SEASONALD->
				start_story_quiz_for_test(player);
			quiz_completed = (int)quiz_started["ok"] &&
				!has_index((mapping)quiz_started["question"],"answer");
			for(int question=1;question<=10;question++){
				mapping answer = SEASONALD->answer_story_quiz_for_test(
					player,question,(int)((array)story_config["quiz"])
						[question-1]["answer"]);
				if(!(int)answer["ok"] || !(int)answer["correct"])
					quiz_completed = 0;
			}
			mapping quiz_result = SEASONALD->query_story_quiz(player);
			check("代表人物完成八十一章后可答完十问并获得满分阅历",
				quiz_completed && (int)quiz_result["best_score"]==10 &&
				(string)quiz_result["best_title"]=="人间见证者" &&
				(int)quiz_result["perfect"],sprintf("quiz=%O",quiz_result));
		}

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
			validate_illusion_quest_items(restored,account_id) &&
			(string)restored_skill["profession"]==profession_id,
			sprintf("saved=%d restored=%d equipped=%d skill=%O",saved,
				restored_ok,count_equipped_newmoon_items(restored),
				restored_skill));
		if(index==0){
			mapping restored_quiz = SEASONALD->query_story_quiz(restored);
			check("重启式存档重载后十问最高分、称号与满分后记不丢失",
				quiz_completed && (int)restored_quiz["ok"] &&
				(int)restored_quiz["best_score"]==10 &&
				(string)restored_quiz["best_title"]=="人间见证者" &&
				(int)restored_quiz["perfect"] &&
				sizeof((string)restored_quiz["epilogue"])>100,
				sprintf("quiz=%O",restored_quiz));
		}

		if(index==0){
			restored["/tmp/illusion_settle_throw_for_test"] = 1;
			mapping thrown_settle=SEASONALD->settle_player_for_test(restored);
			restored->m_delete_foruser(
				"/tmp/illusion_settle_throw_for_test");
			object released_key=ACCOUNT_CHARACTERD->
				query_account_runtime_mutex(character_id)->trylock();
			check("回归内部异常转为可重试失败且同账号运行锁必释放",
				!(int)thrown_settle["ok"] && released_key!=0,
				sprintf("result=%O lock=%O",thrown_settle,released_key));
			if(released_key)
				destruct(released_key);
		}
		if(index==0)
			restored["/tmp/illusion_settle_post_commit_throw_for_test"] = 1;
		mapping settled = SEASONALD->settle_player_for_test(restored);
		restored->m_delete_foruser(
			"/tmp/illusion_settle_post_commit_throw_for_test");
		if(index==0)
			check("账号索引提交后的会话异常仍明确回归成功且标记降级",
				(int)settled["ok"] &&
				(int)settled["post_commit_degraded"] &&
				search((array)settled["post_commit_warnings"],
					"difficulty_scope")!=-1,
				sprintf("settled=%O",settled));
		if(index==0){
			restored["/tmp/illusion_settle_throw_for_test"] = 1;
			mapping authoritative_retry=SEASONALD->
				settle_player_for_test(restored);
			restored->m_delete_foruser(
				"/tmp/illusion_settle_throw_for_test");
			check("结算异常边界反查已回归索引时不误报可重复失败",
				(int)authoritative_retry["ok"] &&
				(int)authoritative_retry["already"] &&
				(int)authoritative_retry["post_commit_degraded"] &&
				search((array)authoritative_retry["post_commit_warnings"],
					"authoritative_recheck")!=-1,
				sprintf("result=%O",authoritative_retry));
		}
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
			validate_newmoon_items(player,account_id,profession_id) &&
			validate_illusion_quest_items(player,account_id),
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
	check("八十一章的二十五个关键故事事件及中文地点配置完整",
		load_story_events(),sprintf("events=%d",sizeof(story_events)));
	check("S1六档猎场与九名剧情首领严格贴合人物成长等级",
		validate_s1_training_levels(),"S1怪物等级与章回成长仍有断层");
	int profession_names_complete = 1;
	foreach(professions,mapping profession)
		if(TASKD->query_growth_task_profession_name(
		   (string)profession["profession"])!=(string)profession["name"])
			profession_names_complete = 0;
	check("十二职业榜单名称完整且无相太极不显示未知职业",
		profession_names_complete,"职业中文名目录不完整");
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
	mapping denied_quiz_start = SEASONALD->
		start_story_quiz_for_test(unauthorized);
	mapping denied_quiz_answer = SEASONALD->
		answer_story_quiz_for_test(unauthorized,1,1);
	int denied_quiz_save_failure = SEASONALD->
		force_next_story_quiz_save_failure_for_test(unauthorized);
	mapping denied_settle = SEASONALD->settle_player_for_test(unauthorized);
	check("测试专用建角、路线、奖励、十问与结算入口对普通账号全部失败关闭",
		!(int)denied_create["ok"] && !(int)denied_route["ok"] &&
		!(int)denied_secret["ok"] && !(int)denied_claim["ok"] &&
		!(int)denied_quiz_start["ok"] &&
		!(int)denied_quiz_answer["ok"] &&
		!denied_quiz_save_failure &&
		!(int)denied_settle["ok"],
		sprintf("create=%O route=%O secret=%O claim=%O quiz=%O/%O/%d settle=%O",
			denied_create,denied_route,denied_secret,denied_claim,
			denied_quiz_start,denied_quiz_answer,
			denied_quiz_save_failure,denied_settle));
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
