#!/usr/bin/env pike
/** 本命灵伴角色隔离、收集培养、装备、唯一战斗位与PVE/PVP回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);
array(object) test_players = ({});
array(string) test_userids = ({});
string test_account = "xd99testunitspirit";
object|zero test_room = 0;

void check(string name,int valid,string reason)
{
	test_results["total"]++;
	if(valid){ test_results["passed"]++; werror("  ✓ %s\n",name); }
	else{ test_results["failed"]++; werror("  ✗ %s: %s\n",name,reason); }
}

string user_file(string userid)
{
	return DATA_ROOT+"u/"+userid[sizeof(userid)-2..]+"/"+userid+".o";
}

string shared_pet_file(string account_id)
{
	return DATA_ROOT+"accounts/"+
		account_id[sizeof(account_id)-2..]+"/"+
		account_id+".pets.json";
}

void remove_user_file(string userid)
{
	string path = user_file(userid);
	rm(path); rm(path+".tmp"); rm(path+".bak"); rm(path+".bak.tmp");
}

void cleanup_test_data()
{
	foreach(test_players,object player)
		if(player) catch(destruct(player));
	test_players = ({});
	PETD->remove_test_pet_data(test_account);
	ACCOUNT_CHARACTERD->remove_test_account(test_account);
	foreach(test_userids,string userid)
		remove_user_file(userid);
	remove_user_file(test_account);
	test_userids = ({});
	if(test_room) catch(destruct(test_room));
	test_room = 0;
}

object create_root_player()
{
	cleanup_test_data();
	object player = clone(GAMELIB_USER);
	player->set_name(test_account);
	player->set_password("testunit88");
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn = "灵伴根人物";
	player->setup("testunit-only");
	player->set_raceId("human");
	player->set_profeId("jianxian");
	player->setup_player("human","jianxian");
	player->level = 80;
	player->set_att_by_level();
	player->set_term("noterm");
	player->save_with_result();
	test_players += ({player});
	test_userids += ({test_account});
	return player;
}

object restore_character(string character_id,string race,string profession)
{
	object player = clone(GAMELIB_USER);
	player->set_name(character_id);
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->restore(); player->restore();
	player->set_raceId(race);
	player->set_profeId(profession);
	player->setup_player(race,profession);
	player->level = 80;
	player->set_att_by_level();
	player->set_term("noterm");
	player->save_with_result();
	test_players += ({player});
	if(search(test_userids,character_id)==-1)
		test_userids += ({character_id});
	return player;
}

void test_isolated_collection_and_shared_compatibility(object root,
	object child)
{
	werror("\n【本命灵伴测试】角色隔离与共享宠物零改写\n");
	mapping shared_chosen = PETD->choose_starter_pet(root,"lushu");
	string before = Stdio.read_file(shared_pet_file(test_account));
	mapping root_chosen = SPIRIT_COMPANIOND->choose_spirit_companion(
		root,"qingyuanli");
	mapping child_chosen = SPIRIT_COMPANIOND->choose_spirit_companion(
		child,"zhufengquan");
	mapping root_state = SPIRIT_COMPANIOND->query_spirit_companion_state(root);
	mapping child_state = SPIRIT_COMPANIOND->query_spirit_companion_state(child);
	string after = Stdio.read_file(shared_pet_file(test_account));
	check("共享宠物原档逐字节保持不变",
		shared_chosen["ok"] && before && before==after,
		"本命初遇迁移、复制或改写了共享宠物文件");
	check("同注册账号两个角色拥有不同本命档案与唯一ID",
		root_chosen["ok"] && child_chosen["ok"] &&
		root_state["owner_id"]==root->query_name() &&
		child_state["owner_id"]==child->query_name() &&
		root_state["pets"][0]["id"]!=child_state["pets"][0]["id"] &&
		root_state["pets"][0]["species"]=="qingyuanli" &&
		child_state["pets"][0]["species"]=="zhufengquan",
		"角色档案、物种或唯一ID仍发生共享");
	check("初遇提供8种图鉴、独立材料和三槽装备",
		sizeof((mapping)root_state["catalog"])==8 &&
		sizeof((array)root_state["gear_inventory"])==3 &&
		sizeof((mapping)root_state["pets"][0]["equipment"])==3 &&
		(int)root_state["materials"]["companion_food"]==10 &&
		(int)root_state["materials"]["craft_shard"]==6 &&
		(int)root_state["materials"]["spirit_thread"]==3,
		"图鉴、材料匣或初遇装备缺失");
	check("共享宠物图鉴只读提供本命共鸣且不改变原档",
		(int)root_state["shared_resonance_bonus"]==1 &&
		Stdio.read_file(shared_pet_file(test_account))==before,
		"共享图鉴共鸣缺失、越界或查询时改写了共享档案");
	mapping repeat = SPIRIT_COMPANIOND->choose_spirit_companion(
		root,"yunlingque");
	check("本命初遇不可重复覆盖",!repeat["ok"],
		"重复初遇覆盖了现有人物灵伴档案");
	mapping interaction = SPIRIT_COMPANIOND->interact_spirit_companion(root);
	root_state = SPIRIT_COMPANIOND->query_spirit_companion_state(root);
	child_state = SPIRIT_COMPANIOND->query_spirit_companion_state(child);
	check("陪伴成长与材料严格按角色隔离",
		interaction["ok"] &&
		(int)root_state["materials"]["companion_food"]==12 &&
		(int)child_state["materials"]["companion_food"]==10 &&
		(int)root_state["pets"][0]["bond"]==2 &&
		(int)child_state["pets"][0]["bond"]==1,
		"主角色互动改变了子角色材料或亲密度");
}

void test_collection_and_gear(object root)
{
	werror("\n【本命灵伴测试】稳定收集、材料与装备闭环\n");
	mapping explore = ([]);
	for(int i=0;i<3;i++){
		mapping record = root["/spirit_companion/record"];
		record["daily_key"] = 1;
		record["daily_explore"] = 0;
		explore = SPIRIT_COMPANIOND->explore_spirit_companion(root);
	}
	mapping state = SPIRIT_COMPANIOND->query_spirit_companion_state(root);
	check("每3次寻踪稳定发现未收录灵伴且每天幂等",
		explore["ok"] && (string)explore["discovered"]!="" &&
		sizeof((array)state["pets"])==2 &&
		(int)state["explore_progress"]==3,
		"寻踪没有形成确定性收集进度");
	mapping forge = SPIRIT_COMPANIOND->forge_spirit_gear(root,"wind_bell");
	state = SPIRIT_COMPANIOND->query_spirit_companion_state(root);
	string active_id = (string)state["active_id"];
	string forged_id = forge["ok"] ? (string)forge["gear"]["id"] : "";
	mapping equip = forged_id!="" ? SPIRIT_COMPANIOND->equip_spirit_gear(
		root,active_id,forged_id) : ([]);
	state = SPIRIT_COMPANIOND->query_spirit_companion_state(root);
	mapping active = ([]);
	foreach((array)state["pets"],mapping pet)
		if((string)pet["id"]==active_id){ active=pet; break; }
	check("材料可打造并换装，唯一装备不会克隆",
		forge["ok"] && equip["ok"] &&
		(string)active["equipment"]["wind_bell"]==forged_id &&
		(int)state["materials"]["craft_shard"]==7 &&
		(int)state["materials"]["spirit_thread"]==4,
		"打造扣账、换装或唯一装备引用异常");
}

void test_unique_battle_slot(object root)
{
	werror("\n【本命灵伴测试】共享/本命唯一战斗位与PVE/PVP\n");
	check("旧人物缺省继续携带共享宠物",
		SPIRIT_COMPANIOND->query_pet_battle_source(root)=="shared",
		"升级后默认战斗位改变，可能影响老玩家");
	mapping carry = SPIRIT_COMPANIOND->set_pet_battle_source(root,"personal");
	check("可显式切换到本命灵伴且写入角色档案",
		carry["ok"] &&
		SPIRIT_COMPANIOND->query_pet_battle_source(root)=="personal",
		"本命战斗位未持久化");
	test_room = clone(ROOT+"/gamelib/d/jinaodao/yuhuacunguangchang");
	object npc = clone(ROOT+"/gamelib/clone/npc/human_npc/human_gud50");
	root->move(test_room); npc->move(test_room); npc->set_life(100000);
	// 测试夹具临时换为已在图鉴中的疗愈类灵伴，验证新回复链。
	mapping live_record = root["/spirit_companion/record"];
	int live_pet_index = 0;
	for(int live_i=0;live_i<sizeof((array)live_record["pets"]);live_i++)
		if((string)live_record["pets"][live_i]["id"]==
		   (string)live_record["active_id"])
			live_pet_index = live_i;
	live_record["pets"][live_pet_index]["species"] = "yunlingque";
	root->set_life(root->query_life_max()/2);
	root->set_debuff("curse",0,"life");
	root->set_debuff("curse",1,50);
	SPIRIT_COMPANIOND->reset_spirit_companion_combat_state(root);
	int npc_max = npc->query_life_max();
	mapping pve = SPIRIT_COMPANIOND->perform_spirit_companion_combat_assist(
		root,npc);
	mapping pve_repeat = SPIRIT_COMPANIOND->perform_spirit_companion_combat_assist(
		root,npc);
	check("PVE真实协战、有1%上限且受冷却保护",
		pve["ok"] && (int)pve["amount"]>0 &&
		(int)pve["amount"]<=npc_max/100 && !pve_repeat["ok"] &&
		(int)pve["restored"]>0 &&
		(int)pve["restored"]<=root->query_life_max()*3/1000,
		"本命灵伴未参战、越过PVE上限或无冷却");
	root->set_debuff("curse",0,"none");
	root->set_debuff("curse",1,0);
	mapping header_state = HTTP_APID->query_player_state(root);
	check("Vue同时获得双宠位且战斗窗只选本命灵伴",
		mappingp(header_state["pet_slots"]) &&
		header_state["pet_slots"]["battle_source"]=="personal" &&
		header_state["pet_slots"]["shared"]["system"]=="shared" &&
		header_state["pet_slots"]["shared"]["command"]=="pet" &&
		header_state["pet_slots"]["personal"]["system"]=="personal" &&
		header_state["pet_slots"]["personal"]["command"]==
			"spirit_companion" &&
		header_state["pet_slots"]["personal"]["battle_active"] &&
		!header_state["pet_slots"]["shared"]["battle_active"] &&
		header_state["pet_assist"]["system"]=="personal" &&
		mappingp(header_state["pet_assist"]["recent_event"]),
		"Header丢失双宠位、操作命令或战斗窗仍渲染共享宠物");
	object opponent = clone(GAMELIB_USER);
	opponent->set_name("xd99testunitspiritopp");
	opponent->set_password("testunit88");
	opponent->set_project("gamelib");
	opponent->set_raceId("monst");
	opponent->set_profeId("kuangyao");
	opponent->setup_player("monst","kuangyao");
	opponent->level = 80; opponent->set_att_by_level();
	opponent->move(test_room);
	root->fight(opponent,0,1);
	if(!opponent->query_in_combat())
		opponent->_fight(root);
	mapping fast_profile =
		SPIRIT_COMPANIOND->query_spirit_companion_pk_fast_profile(
			root,opponent);
	mapping blocked_shared_profile = PETD->query_pet_pk_fast_profile(
		root,opponent);
	check("快速决胜只读当前本命战斗位而不偷用共享宠物",
		fast_profile["active"] && fast_profile["system"]=="personal" &&
		(int)fast_profile["remaining_uses"]==2 &&
		(int)fast_profile["amount"]<=opponent->query_life_max()/200 &&
		fast_profile["secondary_type"]=="heal" &&
		!blocked_shared_profile["active"],
		"三分钟决胜仍读取共享宠物或丢失本命伤害/疗愈上限");
	root["/tmp/spirit_companion/pvp_at"] = 0;
	mapping pvp1 = SPIRIT_COMPANIOND->perform_spirit_companion_combat_assist(
		root,opponent);
	root["/tmp/spirit_companion/pvp_at"] = 0;
	mapping pvp2 = SPIRIT_COMPANIOND->perform_spirit_companion_combat_assist(
		root,opponent);
	object opponent2 = clone(GAMELIB_USER);
	opponent2->set_name("xd99testunitspiritopp2");
	opponent2->set_password("testunit88");
	opponent2->set_project("gamelib");
	opponent2->set_raceId("human");
	opponent2->set_profeId("yushi");
	opponent2->setup_player("human","yushi");
	opponent2->level = 80; opponent2->set_att_by_level();
	opponent2->move(test_room);
	opponent2->_fight(root);
	root["/tmp/spirit_companion/pvp_at"] = 0;
	mapping pvp3 = SPIRIT_COMPANIOND->perform_spirit_companion_combat_assist(
		root,opponent);
	mapping off_target = SPIRIT_COMPANIOND->perform_spirit_companion_combat_assist(
		root,opponent2);
	mapping hot_switch = SPIRIT_COMPANIOND->set_active_spirit_companion(
		root,(string)SPIRIT_COMPANIOND->query_spirit_companion_state(
			root)["active_id"]);
	mapping hot_feed = SPIRIT_COMPANIOND->feed_spirit_companion(
		root,(string)SPIRIT_COMPANIOND->query_spirit_companion_state(
			root)["active_id"]);
	mapping battle_state = SPIRIT_COMPANIOND->query_spirit_companion_state(root);
	string hot_gear_id = (string)battle_state["gear_inventory"][0]["id"];
	mapping hot_equip = SPIRIT_COMPANIOND->equip_spirit_gear(root,
		(string)battle_state["active_id"],hot_gear_id);
	check("PVP每场最多2次、单次0.5%且不能补刀",
		pvp1["ok"] && pvp2["ok"] && !pvp3["ok"] &&
		(int)pvp1["amount"]<=opponent->query_life_max()/200 &&
		opponent->get_cur_life()>0,
		"PVP未触发、次数/伤害上限失效或直接补刀");
	check("PVP协战只能作用于人物当前真实敌对目标",
		!off_target["ok"],"内部调用可误伤同房其他交战玩家");
	check("战斗中不能切换、喂养或换装刷新协战节奏",
		!hot_switch["ok"] && !hot_feed["ok"] && !hot_equip["ok"],
		"战斗中仍可热切换或培养本命灵伴");
	if(root->query_in_combat())
		root->_clean_fight();
	if(opponent->query_in_combat())
		opponent->_clean_fight();
	if(opponent2->query_in_combat())
		opponent2->_clean_fight();
	destruct(npc); destruct(opponent); destruct(opponent2);
	mapping shared = SPIRIT_COMPANIOND->set_pet_battle_source(root,"shared");
	SPIRIT_COMPANIOND->reset_spirit_companion_combat_state(root);
	object npc2 = clone(ROOT+"/gamelib/clone/npc/human_npc/human_gud50");
	npc2->move(test_room); npc2->set_life(100000);
	mapping blocked = SPIRIT_COMPANIOND->perform_spirit_companion_combat_assist(
		root,npc2);
	check("切回共享宠物后本命协战链立即关闭",
		shared["ok"] && !blocked["ok"] &&
		SPIRIT_COMPANIOND->query_pet_battle_source(root)=="shared",
		"两套宠物在同一战斗位叠加出手");
	destruct(npc2);
}

void test_persistence_and_ui(object child)
{
	werror("\n【本命灵伴测试】重载持久化与UI区分\n");
	string child_id = child->query_name();
	test_players -= ({child}); destruct(child);
	object reloaded = restore_character(child_id,"third","fangshi");
	mapping state = SPIRIT_COMPANIOND->query_spirit_companion_state(reloaded);
	string shared_ui = Stdio.read_file(ROOT+"/gamelib/cmds/pet.pike");
	string personal_ui = Stdio.read_file(
		ROOT+"/gamelib/cmds/spirit_companion.pike");
	string fight_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/inherit/feature/fight.pike");
	string renderer_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/html_renderer.pike");
	string daemon_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/spirit_companiond.pike");
	string vue_html = Stdio.read_file(ROOT+"/vue_source/index.html");
	string vue_js = Stdio.read_file(ROOT+"/vue_source/js/app.js");
	string vue_css = Stdio.read_file(ROOT+"/vue_source/css/app.css");
	object|zero original_player = this_player();
	object|zero shared_command = 0;
	object|zero personal_command = 0;
	int shared_result = 0;
	int personal_result = 0;
	string command_error = "";
	mixed command_err = catch {
		shared_command = (object)(ROOT+"/gamelib/cmds/pet.pike");
		personal_command = (object)(ROOT+
			"/gamelib/cmds/spirit_companion.pike");
		set_this_player(reloaded);
		shared_result = shared_command->main(0);
		personal_result = personal_command->main(0);
	};
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(command_err)
		command_error = describe_error(command_err)+" "+
			describe_backtrace(command_err);
	check("角色重载后灵伴、材料与装备从唯一.o档案恢复",
		state["ok"] && state["owner_id"]==child_id &&
		sizeof((array)state["pets"])==1 &&
		sizeof((array)state["gear_inventory"])==3,
		"重载后独立灵伴状态丢失或读到主角色");
	mapping valid_record = copy_value(reloaded["/spirit_companion/record"]);
	reloaded["/spirit_companion/record"]["gear_inventory"][0][
		"attack_bonus"] = 999999;
	mapping corrupt_presence =
		SPIRIT_COMPANIOND->query_spirit_companion_presence(reloaded);
	reloaded["/spirit_companion/record"] = valid_record;
	check("损坏装备增益不能绕过战斗热路径的完整档案校验",
		!corrupt_presence["active"],
		"异常增益档仍可生成本命协战卡位或进入公式");
	check("名称、紫色UI、命令与共享宠物入口完全区分",
		search(shared_ui,"共享宠物·山海万灵谱")!=-1 &&
		search(personal_ui,"§5【本命灵伴】§r")!=-1 &&
		search(personal_ui,"灵伴图鉴")!=-1 &&
		search(personal_ui,"材料匣")!=-1 &&
		search(personal_ui,"装备工坊")!=-1 &&
		search(fight_source,"query_pet_battle_source")!=-1 &&
		search(renderer_source,"result[\"pet_slots\"]")!=-1 &&
		search(renderer_source,"pet_battle_source==\"personal\"")!=-1 &&
		search(daemon_source,"quality_roll = random(100)")!=-1 &&
		search(daemon_source,"record[\"revision\"]%4")==-1 &&
		search(vue_html,"header-pet-slots")!=-1 &&
		search(vue_html,"@click=\"sendQuickCommand(slot.command)\"")!=-1 &&
		search(vue_html,"sendQuickCommand('pet')")!=-1 &&
		search(vue_html,"sendQuickCommand('spirit_companion')")!=-1 &&
		search(vue_html,"共享宠物</button>")!=-1 &&
		search(vue_html,"本命灵伴</button>")!=-1 &&
		search(vue_js,"getPetSlotTitle(slot)")!=-1 &&
		search(vue_js,
			"index === 0 ? 'pet' : 'spirit_companion'")!=-1 &&
		search(vue_css,"pet-system-personal")!=-1,
		"新旧系统仍共用名称、视觉、入口或双宠战斗链");
	check("共享宠物与本命灵伴命令可真实加载并执行各自首页",
		!command_err && shared_command && personal_command &&
		shared_result==1 && personal_result==1,
		"命令编译、只读首页或双向入口失败: "+command_error);
}

int main()
{
	werror("\n========== 本命灵伴完整测试 ==========\n");
	mixed err = catch{
		object root = create_root_player();
		mapping created = ACCOUNT_CHARACTERD->create_character(
			test_account,"third","fangshi");
		object child = created["ok"] ? restore_character(
			(string)created["character"]["id"],"third","fangshi") : 0;
		check("测试账号可建立独立子角色",created["ok"] && objectp(child),
			"账号角色索引创建失败");
		test_isolated_collection_and_shared_compatibility(root,child);
		test_collection_and_gear(root);
		test_unique_battle_slot(root);
		test_persistence_and_ui(child);
	};
	if(err)
		check("测试运行无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	cleanup_test_data();
	werror("\n本命灵伴测试：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
