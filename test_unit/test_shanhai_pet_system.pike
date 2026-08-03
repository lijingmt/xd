#!/usr/bin/env pike
/** 山海万灵账号收藏、养成、PVE/PVP协战、裂隙与论道完整回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);
array(object) test_players = ({});
array(string) test_accounts = ({});
object|zero test_room = 0;
string test_team_id = "";
object|zero original_player = 0;

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

string pet_file(string account_id)
{
	return DATA_ROOT+"accounts/"+
		account_id[sizeof(account_id)-2..]+"/"+
		account_id+".pets.json";
}

void cleanup_player_file(string userid)
{
	string path = player_file(userid);
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
}

void cleanup_account(string account_id)
{
	PETD->remove_test_pet_data(account_id);
	ACCOUNT_CHARACTERD->remove_test_account(account_id);
	cleanup_player_file(account_id);
}

object create_test_player(string userid,string race,string profession)
{
	cleanup_account(userid);
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(userid);
	player->set_password("testunit88");
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->name_cn = "万灵测试"+userid[sizeof(userid)-2..];
	player->setup("testunit-only");
	player->set_raceId(race);
	player->set_profeId(profession);
	player->setup_player(race,profession);
	player->level = 14;
	player->set_att_by_level();
	player->set_term("noterm");
	player->packageLevel = 20;
	player->packaged_items = ({});
	player->save_with_result();
	test_players += ({player});
	test_accounts += ({userid});
	return player;
}

object restore_child_player(string character_id,string race,
	string profession)
{
	object player = clone(GAMELIB_USER);
	if(!player)
		return 0;
	player->set_name(character_id);
	player->set_project("gamelib");
	player->set_userip("testunit");
	player->restore();
	player->set_raceId(race);
	player->set_profeId(profession);
	player->setup_player(race,profession);
	player->level = 50;
	player->set_att_by_level();
	player->set_term("noterm");
	player->save_with_result();
	test_players += ({player});
	return player;
}

int is_hex_pet_id(string value)
{
	if(!value || sizeof(value)!=64)
		return 0;
	for(int i=0;i<sizeof(value);i++)
		if(!((value[i]>='0' && value[i]<='9') ||
		   (value[i]>='a' && value[i]<='f')))
			return 0;
	return 1;
}

object make_npc(object player,int level)
{
	object npc = clone(ROOT+"/gamelib/clone/npc/kunlunshan/qinyuan1");
	if(!npc)
		return 0;
	npc->_npcLevel = level;
	npc->setup_npc_dongtai(player);
	if(test_room)
		npc->move(test_room);
	return npc;
}

mapping find_pet_species(mapping state,string species)
{
	foreach((array)state["pets"],mapping pet)
		if((string)pet["species"]==species)
			return pet;
	return ([]);
}

mapping run_rift(array(object) players,int correct)
{
	mapping state = ([]);
	for(int guard=0;guard<16;guard++){
		state = PETD->query_rift_state(players[0]);
		if(!state["ok"] || state["status"]!="active")
			break;
		string expected = (string)state["mechanic"];
		string action = expected;
		if(!correct)
			action = expected=="break" ? "guard" : "break";
		foreach(players,object player)
			PETD->take_rift_action(player,action);
	}
	return PETD->query_rift_state(players[0]);
}

void test_catalog_and_all_professions(array(object) players)
{
	werror("\n【万灵测试】图鉴与全职业初契\n");
	mapping catalog = PETD->query_pet_catalog();
	array(string) starters = PETD->query_starter_species();
	array(string) bosses = PETD->query_rift_boss_species();
	int valid_catalog = sizeof(catalog)==15 && sizeof(starters)==3 &&
		sizeof(bosses)==5;
	foreach(catalog;string species;mapping info)
		valid_catalog = valid_catalog && sizeof((array)info["skill_sets"])==3 &&
			sizeof((array)info["skill_sets"][0])==3 &&
			(string)info["name"]!="" && (string)info["origin"]!="";
	check("15种异兽、3只初契、5只轮替首领和三套灵纹完整",
		valid_catalog,"图鉴数量、文化小传或灵纹配置不完整");

	object first = players[0];
	mapping read_only = PETD->query_pet_state(first);
	mapping too_early = PETD->choose_starter_pet(first,"dangkang");
	check("旧账号读取与14级误点都不创建宠物附属文件",
		read_only["ok"] && !too_early["ok"] &&
		Stdio.file_size(pet_file(first->query_name()))<=0,
		"只读兼容路径写盘或提前领取成功");

	array(string) choices = ({"dangkang","lushu","wenyaoyu"});
	int all_ok = 1;
	for(int i=0;i<sizeof(players);i++){
		players[i]->level = 50;
		players[i]->set_att_by_level();
		mapping chosen = PETD->choose_starter_pet(players[i],
			choices[i%sizeof(choices)]);
		mapping state = PETD->query_pet_state(players[i]);
		all_ok = all_ok && chosen["ok"] && state["starter_claimed"]==1 &&
			sizeof((array)state["pets"])==1 &&
			is_hex_pet_id((string)state["pets"][0]["id"]) &&
			state["active"][players[i]->query_name()]==state["pets"][0]["id"];
	}
	check("人、妖、中立阵营现有全部十职业均可在15级后独立完成初契",
		all_ok,"至少一个职业被职业判断、存档或唯一ID拦截");
}

void test_collection_growth(object player)
{
	werror("\n【万灵测试】收藏、培养和独立材料\n");
	mapping before = PETD->query_pet_state(player);
	string pet_id = (string)before["pets"][0]["id"];
	array inventory_before = copy_value(player->packaged_items);
	mapping duplicate = PETD->test_grant_pet_species(player,"dangkang");
	mapping after_duplicate = PETD->query_pet_state(player);
	check("同种异兽不复制实例而转为10枚灵卵残片",
		duplicate["ok"] && duplicate["duplicate"] &&
		sizeof((array)after_duplicate["pets"])==1 &&
		(int)after_duplicate["materials"]["egg_fragment"]==10,
		"重复图鉴生成第二个实例或残片数量错误");

	PETD->test_add_pet_material(player,"spirit_dew",1000);
	PETD->test_add_pet_material(player,"bond_token",20);
	PETD->test_add_pet_material(player,"skill_rune",3);
	int growth_ok = 1;
	for(int i=1;i<60;i++)
		growth_ok = growth_ok && PETD->train_pet_level(player,pet_id)["ok"];
	mapping level_reject = PETD->train_pet_level(player,pet_id);
	for(int i=1;i<5;i++)
		growth_ok = growth_ok && PETD->deepen_pet_bond(player,pet_id)["ok"];
	mapping bond_reject = PETD->deepen_pet_bond(player,pet_id);
	mapping state0 = PETD->query_pet_state(player);
	array skills0 = copy_value(state0["pets"][0]["skills"]);
	mapping reset1 = PETD->reset_pet_skills(player,pet_id);
	array skills1 = copy_value(PETD->query_pet_state(player)["pets"][0]["skills"]);
	mapping reset2 = PETD->reset_pet_skills(player,pet_id);
	array skills2 = copy_value(PETD->query_pet_state(player)["pets"][0]["skills"]);
	mapping reset3 = PETD->reset_pet_skills(player,pet_id);
	array skills3 = copy_value(PETD->query_pet_state(player)["pets"][0]["skills"]);
	PETD->test_add_pet_material(player,"egg_fragment",260);
	for(int star=1;star<10;star++)
		growth_ok = growth_ok && PETD->upgrade_pet_star(player,pet_id)["ok"];
	mapping star_reject = PETD->upgrade_pet_star(player,pet_id);
	mapping grown = PETD->query_pet_state(player);
	string skills0_json = Standards.JSON.encode(skills0);
	string skills1_json = Standards.JSON.encode(skills1);
	string skills2_json = Standards.JSON.encode(skills2);
	string skills3_json = Standards.JSON.encode(skills3);
	check("培养严格封顶60级、十星、五阶羁绊且三套灵纹确定轮换",
		growth_ok && !level_reject["ok"] && !star_reject["ok"] &&
		!bond_reject["ok"] &&
		(int)grown["pets"][0]["level"]==60 &&
		(int)grown["pets"][0]["star"]==10 &&
		(int)grown["pets"][0]["evolution"]==3 &&
		grown["pets"][0]["evolution_name"]=="真形·圆满" &&
		(int)grown["pets"][0]["bond"]==5 &&
		reset1["ok"] && reset2["ok"] && reset3["ok"] &&
		skills0_json!=skills1_json && skills1_json!=skills2_json &&
		skills0_json==skills3_json,
		"等级/星级/羁绊越界、进化错误或灵纹不是确定三轮回");
	check("五维属性、战力与PVE/PVP两套成长压缩值确定且完整",
		mappingp(grown["pets"][0]["attributes"]) &&
		(int)grown["pets"][0]["attributes"]["life"]>0 &&
		(int)grown["pets"][0]["attributes"]["attack"]>0 &&
		(int)grown["pets"][0]["attributes"]["defense"]>0 &&
		(int)grown["pets"][0]["attributes"]["spirit"]>0 &&
		(int)grown["pets"][0]["attributes"]["speed"]>0 &&
		(int)grown["pets"][0]["power"]>0 &&
		(int)grown["pets"][0]["growth_percent"]==222 &&
		(int)grown["pets"][0]["pvp_growth_percent"]==124,
		"属性缺字段、战力无效或PVP没有压缩到完整成长的20%");
	check("所有培养材料保存在独立材料栏且不污染人物背包",
		player->packaged_items==inventory_before &&
		mappingp(grown["materials"]) && sizeof((mapping)grown["materials"])==6,
		"培养过程改写了人物背包或材料栏字段不完整");
	string boss_species = PETD->query_rift_boss_species()[0];
	PETD->test_add_pet_material(player,"egg_fragment",60);
	mapping hatched = PETD->hatch_pet_fragments(player,boss_species);
	mapping hatch_repeat = PETD->hatch_pet_fragments(player,boss_species);
	mapping after_hatch = PETD->query_pet_state(player);
	PETD->test_add_pet_material(player,"cosmetic_dust",40);
	mapping variant_result = PETD->unlock_pet_dust_variant(player,pet_id);
	mapping variant_repeat = PETD->unlock_pet_dust_variant(player,pet_id);
	mapping after_variant = PETD->query_pet_state(player);
	check("60枚残片可任选裂隙异兽稳定孵化且已收录物种不重复扣除",
		hatched["ok"] && !hatch_repeat["ok"] &&
		sizeof((array)after_hatch["pets"])==2 &&
		(int)after_hatch["materials"]["egg_fragment"]==0,
		"残片没有消费出口、重复孵化生成实例或多扣材料");
	check("40份月华尘可保底解锁纯外观且重复点击不再扣除",
		variant_result["ok"] && !variant_repeat["ok"] &&
		search((array)after_variant["pets"][0]["variants"],
			"星辉异色")!=-1 &&
		(int)after_variant["materials"]["cosmetic_dust"]==0,
		"月华尘无消费出口、重复扣除或未写入永久外观");
}

void test_same_account_active_pet()
{
	werror("\n【万灵测试】同账号多人物协战互斥\n");
	string account_id = "xd99testunitpetsame";
	object root_player = create_test_player(account_id,"human","jianxian");
	root_player->level = 50;
	root_player->set_att_by_level();
	root_player->save_with_result();
	mapping created = ACCOUNT_CHARACTERD->create_character(
		account_id,"third","fangshi");
	object child = created["ok"] ? restore_child_player(
		(string)created["character"]["id"],"third","fangshi") : 0;
	mapping chosen = PETD->choose_starter_pet(root_player,"lushu");
	mapping state = PETD->query_pet_state(root_player);
	string pet_id = sizeof((array)state["pets"]) ?
		(string)state["pets"][0]["id"] : "";
	mapping occupied = child ? PETD->set_active_pet(child,pet_id) : ([]);
	check("同账号在线人物不能让同一灵宠同时协战",
		created["ok"] && child && chosen["ok"] && !occupied["ok"],
		"同一宠物被两个在线人物同时激活");
	if(root_player){
		test_players -= ({root_player});
		destruct(root_player);
	}
	mapping transferred = child ? PETD->set_active_pet(child,pet_id) : ([]);
	mapping child_state = child ? PETD->query_pet_state(child) : ([]);
	check("原人物离线后可安全把伙伴转交给同账号另一人物",
		transferred["ok"] && child_state["active"][child->query_name()]==pet_id,
		"离线占用未清理或转交后账号记录不一致");
	object relogged_root = restore_child_player(
		account_id,"human","jianxian");
	if(relogged_root && child){
		relogged_root->move(test_room);
		child->move(test_room);
	}
	mapping same_account_duel = relogged_root && child ?
		PETD->invite_pet_duel(relogged_root,child->query_name()) : ([]);
	check("同账号不同职业即使同时在线同房也不能互刷灵宠论道",
		relogged_root && child && !same_account_duel["ok"],
		"同账号多职业可以建立有奖论道邀请");
}

void test_legacy_pet_migration()
{
	werror("\n【万灵测试】V1旧宠物档案无损迁移\n");
	string account_id = "xd99testunitpetlegacy";
	object player = create_test_player(account_id,"human","jianxian");
	player->level = 50;
	player->set_att_by_level();
	player->save_with_result();
	mapping chosen = PETD->choose_starter_pet(player,"dangkang");
	string path = pet_file(account_id);
	mapping legacy = Standards.JSON.decode(Stdio.read_file(path));
	legacy["version"] = 1;
	foreach((array)legacy["pets"],mapping pet)
		m_delete(pet,"star");
	string legacy_source = Standards.JSON.encode(legacy);
	Stdio.write_file(path,legacy_source);
	rm(path+".bak");
	PETD->drop_test_pet_cache(account_id);
	mapping migrated = PETD->query_pet_state(player);
	mapping disk_after_read = Standards.JSON.decode(Stdio.read_file(path));
	int mutation = PETD->test_add_pet_material(player,"spirit_dew",1);
	mapping disk_after_write = Standards.JSON.decode(Stdio.read_file(path));
	check("V1档案读取时补为一星且单纯查看不强制改写磁盘",
		chosen["ok"] && migrated["ok"] &&
		(int)migrated["version"]==2 &&
		(int)migrated["pets"][0]["star"]==1 &&
		(int)disk_after_read["version"]==1 &&
		!has_index(disk_after_read["pets"][0],"star"),
		"旧档案无法读取、星级不是安全默认值或查看触发了批量迁移");
	check("旧档案下一次真实修改通过原子保存自然升级为V2",
		mutation && (int)disk_after_write["version"]==2 &&
		(int)disk_after_write["pets"][0]["star"]==1,
		"V1内存迁移后无法保存或永久星级字段丢失");
}

void test_hunt_and_assist(object player,object pvp_target)
{
	werror("\n【万灵测试】真实寻迹与PVE/PVP御灵协战\n");
	player->move(test_room);
	pvp_target->move(test_room);
	mapping hunt_before = PETD->query_pet_state(player);
	mapping start = PETD->start_pet_hunt(player);
	object first = make_npc(player,45);
	object low = make_npc(player,44);
	object second = make_npc(player,45);
	object third = make_npc(player,45);
	mapping hit1 = PETD->record_pet_hunt_kill(player,first);
	mapping repeated = PETD->record_pet_hunt_kill(player,first);
	mapping low_hit = PETD->record_pet_hunt_kill(player,low);
	mapping hit2 = PETD->record_pet_hunt_kill(player,second);
	mapping hit3 = PETD->record_pet_hunt_kill(player,third);
	mapping state = PETD->query_pet_state(player);
	check("寻迹只认三只合适等级的不同真实NPC且同一死亡不可重复计数",
		start["ok"] && hit1["ok"] && !repeated["ok"] &&
		!low_hit["ok"] && hit2["ok"] && hit3["completed"] &&
		(int)state["daily"]["hunt"]==4 &&
		(int)state["materials"]["egg_fragment"]==
			(int)hunt_before["materials"]["egg_fragment"]+2 &&
		(int)state["materials"]["spirit_dew"]==
			(int)hunt_before["materials"]["spirit_dew"]+8,
		"重复死亡、低级怪或点击页面增加了寻迹进度");

	player->set_life(player->query_life_max()/2);
	player->set_debuff("curse",0,"life");
	player->set_debuff("curse",1,50);
	player->set_debuff("curse",2,10);
	player["/tmp/wanling/assist_at"] = 0;
	int life_before = player->get_cur_life();
	int npc_before = first->get_cur_life();
	mapping assist = PETD->perform_pet_pve_assist(player,first);
	mapping cooldown = PETD->perform_pet_pve_assist(player,first);
	mapping presence = PETD->query_pet_battle_presence(player);
	int expected_max = player->query_life_max()*2/100*
		(int)presence["growth_percent"]/100/2;
	check("疗愈伙伴30秒低频触发并遵循现有减疗上限规则",
		assist["ok"] && assist["type"]=="heal" &&
		(int)assist["amount"]>0 && (int)assist["amount"]<=expected_max &&
		!cooldown["ok"] && first->get_cur_life()==npc_before &&
		player->get_cur_life()>life_before,
		"协战忽略冷却、减疗或错误修改NPC生命");
	check("协战事件向战斗小窗提供宠物、技能、冷却和唯一事件编号",
		presence["active"] && presence["name"]=="当康" &&
		presence["icon"]!="" && presence["skill"]=="丰穰守心" &&
		(int)presence["level"]==60 && (int)presence["star"]==10 &&
		presence["evolution_name"]=="真形·圆满" &&
		(int)presence["power"]>0 && presence["combat_mode"]=="pve" &&
		(int)presence["cooldown_remaining"]>0 &&
		(int)presence["cooldown_remaining"]<=30 &&
		mappingp(presence["recent_event"]) &&
		(string)presence["recent_event"]["id"]!="" &&
		presence["recent_event"]["type"]=="heal" &&
		presence["recent_event"]["mode"]=="pve" &&
		(int)presence["recent_event"]["amount"]==(int)assist["amount"],
		"战斗API无法可靠渲染随行卡片或协战动画");
	string event_id = (string)presence["recent_event"]["id"];
	player->set_life(player->query_life_max()/2);
	player->fight(pvp_target,0,1);
	if(!pvp_target->query_in_combat())
		pvp_target->_fight(player);
	mapping combat_switch = PETD->set_active_pet(player,"none");
	check("人物交战中不能暂停、更换或培养灵宠以临场套利",
		!combat_switch["ok"] &&
		search((string)combat_switch["message"],"交战中")!=-1,
		"战斗中仍可热切换灵宠或清空御灵次数");
	int target_before = pvp_target->get_cur_life();
	mapping pvp = ([]);
	int charged = 1;
	for(int round=1;round<=5;round++){
		pvp = PETD->perform_pet_combat_assist(player,pvp_target);
		if(round<5)
			charged = charged && !pvp["ok"] && pvp["charging"] &&
				(int)pvp["charge"]==round;
	}
	mapping after_pvp_presence = PETD->query_pet_battle_presence(player);
	check("人物PVP按五个有效战斗节拍充能后触发且疗愈宠不伤害对手",
		charged && pvp["ok"] && pvp["type"]=="heal" &&
		pvp_target->get_cur_life()==target_before &&
		player->get_cur_life()>player->query_life_max()/2 &&
		after_pvp_presence["combat_mode"]=="pvp" &&
		(int)after_pvp_presence["pvp_uses"]==1 &&
		(int)after_pvp_presence["pvp_uses_max"]==2 &&
		mappingp(after_pvp_presence["recent_event"]) &&
		after_pvp_presence["recent_event"]["mode"]=="pvp" &&
		after_pvp_presence["recent_event"]["target_name"]==
			player->query_name_cn() &&
		(string)after_pvp_presence["recent_event"]["id"]!=event_id,
		"PVP充能、限次状态、模式事件、治疗目标或角色边界错误");
	for(int round=1;round<=5;round++)
		PETD->perform_pet_combat_assist(player,pvp_target);
	mapping exhausted = PETD->perform_pet_combat_assist(player,pvp_target);
	check("同一场人物PVP最多触发两次御灵协战",
		!exhausted["ok"] &&
		(int)PETD->query_pet_battle_presence(player)["pvp_uses"]==2,
		"PVP切换目标或继续心跳可绕过每场两次限制");
	if(player->query_in_combat())
		player->_clean_fight();
	if(pvp_target->query_in_combat())
		pvp_target->_clean_fight();
	player->set_life(player->query_life_max());
	player["/tmp/wanling/assist_at"] = 0;
	mapping full_life_assist = PETD->perform_pet_pve_assist(player,first);
	mapping full_life_presence = PETD->query_pet_battle_presence(player);
	check("生命已满时仍生成零数值陪伴事件但不伪造治疗量",
		full_life_assist["ok"] && (int)full_life_assist["amount"]==0 &&
		(string)full_life_presence["recent_event"]["id"]!=event_id &&
		(int)full_life_presence["recent_event"]["amount"]==0,
		"满生命时宠物完全无反馈、重复事件ID或显示虚假回血");
	mapping granted_attack = PETD->test_grant_pet_species(player,"bifang");
	mapping attack_state = PETD->query_pet_state(player);
	string attack_pet_id = "";
	foreach((array)attack_state["pets"],mapping pet)
		if(pet["species"]=="bifang")
			attack_pet_id = (string)pet["id"];
	mapping activated_attack = PETD->set_active_pet(player,attack_pet_id);
	int pvp_life_max = pvp_target->query_life_max();
	pvp_target->set_life(2);
	player->fight(pvp_target,0,1);
	if(!pvp_target->query_in_combat())
		pvp_target->_fight(player);
	mapping last_hit_guard = ([]);
	for(int round=1;round<=5;round++)
		last_hit_guard = PETD->perform_pet_combat_assist(player,pvp_target);
	check("强攻宠参与人物PVP但绝不造成最后一击",
		granted_attack["ok"] && activated_attack["ok"] &&
		last_hit_guard["ok"] && last_hit_guard["type"]=="damage" &&
		(int)last_hit_guard["amount"]==1 && pvp_target->get_cur_life()==1,
		"强攻宠未参与PVP、越过成长上限或直接击杀玩家");
	if(player->query_in_combat())
		player->_clean_fight();
	if(pvp_target->query_in_combat())
		pvp_target->_clean_fight();
	pvp_target->set_life(pvp_life_max);
	mapping profile = PETD->query_pet_assist_profile(
		"bifang",1000000,100000,100000,100000);
	mapping swift = PETD->query_pet_assist_profile(
		"lushu",1000000,100000,100000,100000,1);
	mapping steady = PETD->query_pet_assist_profile(
		"lushu",1000000,100000,100000,100000,2);
	check("强攻协战伤害受目标生命0.2%硬上限约束",
		profile["type"]=="damage" && (int)profile["amount"]==200,
		"高面板可绕过协战贡献上限");
	check("三套灵纹对应均衡、轻灵、厚积三种等价低频节奏",
		(int)swift["amount"]==1600 && (int)swift["cooldown"]==24 &&
		(int)steady["amount"]==2300 && (int)steady["cooldown"]==36,
		"灵纹仅改名字、倍率失控或冷却没有同步调整");
	mapping pvp_profile = PETD->query_pet_pvp_assist_profile(
		"bifang",1000000,100000,100000,100000,0,124);
	check("PVP成长压缩后强攻单次伤害仍受目标生命约0.5%硬上限",
		pvp_profile["type"]=="damage" &&
		(int)pvp_profile["amount"]==496 &&
		(int)pvp_profile["charge_required"]==5 &&
		(int)pvp_profile["max_uses"]==2,
		"PVP属性可无限放大、触发过密或次数上限丢失");
	player["/tmp/wanling/pvp_target"] = "old_opponent";
	player["/tmp/wanling/pvp_charge"] = 4;
	mapping fast_profile = PETD->query_pet_pk_fast_profile(
		player,pvp_target);
	check("快速决胜切换对手不会继承上一目标的御灵充能",
		fast_profile["active"] && (int)fast_profile["charge"]==0,
		"旧对手充能被带入快速决胜并形成抢先触发");
	player->clean_debuff("curse");
	foreach(({first,low,second,third}),object npc)
		if(npc) destruct(npc);
}

void test_solo_pve_fragment_channels()
{
	werror("\n【万灵测试】单人普通怪、副本与首领残片渠道\n");
	object player = create_test_player("xd99testunitpetpve","human",
		"jianxian");
	player->level = 50;
	player->set_att_by_level();
	PETD->choose_starter_pet(player,"dangkang");
	object normal = make_npc(player,50);
	mapping normal_drop = PETD->test_record_pet_pve_kill(player,normal,0);
	mapping repeated = PETD->test_record_pet_pve_kill(player,normal,0);
	object low = make_npc(player,44);
	mapping low_drop = PETD->test_record_pet_pve_kill(player,low,0);
	object miss = make_npc(player,50);
	mapping missed = PETD->test_record_pet_pve_kill(player,miss,99);
	object boss = make_npc(player,50);
	boss->_boss = 1;
	mapping boss_drop = PETD->test_record_pet_pve_kill(player,boss,29);
	player->fb_id = "testunit/pet_fragment";
	FBD->add_fb_members(player->fb_id,player->query_name());
	object dungeon_boss = make_npc(player,50);
	dungeon_boss->_boss = 1;
	mapping dungeon_drop = PETD->test_record_pet_pve_kill(player,
		dungeon_boss,49);
	FBD->delete_fb_members(player->fb_id,player->query_name());
	player->fb_id = "";
	check("普通同级怪、副本首领和野外首领均可单人获得残片",
		normal_drop["dropped"] && boss_drop["dropped"] &&
		dungeon_drop["dropped"] &&
		(int)normal_drop["chance"]==4 &&
		(int)boss_drop["chance"]==30 &&
		(int)dungeon_drop["chance"]==50,
		"普通怪或副本/BOSS概率渠道未接入真实战斗奖励");
	check("同一怪物按账号去重、低六级怪无收益且概率落空不发残片",
		!repeated["dropped"] && !low_drop["dropped"] &&
		missed["ok"] && !missed["dropped"],
		"重复死亡、低级碾压或未命中概率仍增加残片");
	for(int i=0;i<9;i++){
		object one = make_npc(player,50);
		PETD->test_record_pet_pve_kill(player,one,0);
		destruct(one);
	}
	mapping capped = PETD->query_pet_state(player);
	object extra = make_npc(player,50);
	mapping after_cap = PETD->test_record_pet_pve_kill(player,extra,0);
	mapping capped_after = PETD->query_pet_state(player);
	check("挂机和副本战斗残片按账号每日封顶12枚",
		(int)capped["daily"]["pve_fragments"]==12 &&
		(int)capped["materials"]["egg_fragment"]==12 &&
		!after_cap["dropped"] &&
		(int)capped_after["materials"]["egg_fragment"]==12,
		"每日上限可绕过或材料数量与账号计数不一致");
	foreach(({normal,low,miss,boss,dungeon_boss,extra}),object npc)
		if(npc) destruct(npc);
}

void test_pet_batch_growth_and_fusion()
{
	werror("\n【万灵测试】VIP批量培养与阴阳灵契合成事务\n");
	object player = create_test_player("xd99testunitpetfusion","third",
		"fangshi");
	player->level = 50;
	player->set_att_by_level();
	PETD->choose_starter_pet(player,"dangkang");
	PETD->test_grant_pet_species(player,"jiao");
	PETD->test_grant_pet_species(player,"bifang");
	PETD->test_add_pet_material(player,"spirit_dew",1000);
	PETD->test_add_pet_material(player,"spirit_mark",100);
	mapping before = PETD->query_pet_state(player);
	mapping dangkang = find_pet_species(before,"dangkang");
	mapping jiao = find_pet_species(before,"jiao");
	mapping bifang = find_pet_species(before,"bifang");
	player->set_vip_flag(0);
	player->set_vip_end_time(0);
	mapping denied = PETD->train_pet_levels(player,(string)jiao["id"],10);
	mapping denied_state = PETD->query_pet_state(player);
	player->set_vip_flag(2);
	player->set_vip_end_time(time()+3600);
	mapping trained = PETD->train_pet_levels(player,(string)jiao["id"],10);
	mapping trained_state = PETD->query_pet_state(player);
	check("普通玩家保留单级培养，VIP2可在一次原子保存中安全提升10级",
		!denied["ok"] &&
		(int)find_pet_species(denied_state,"jiao")["level"]==1 &&
		trained["ok"] && (int)trained["trained"]==10 &&
		(int)find_pet_species(trained_state,"jiao")["level"]==11,
		"VIP门槛、批量成本循环或培养等级不正确");
	mapping same_polarity = PETD->query_pet_fusion_preview(player,
		(string)dangkang["id"],(string)jiao["id"]);
	mapping active_reject = PETD->query_pet_fusion_preview(player,
		(string)dangkang["id"],(string)bifang["id"]);
	check("同阴/同阳不能合成且出战宠物不能被消耗",
		!same_polarity["ok"] && !active_reject["ok"] &&
		PETD->query_pet_species_polarity("dangkang")=="yin" &&
		PETD->query_pet_species_polarity("bifang")=="yang",
		"阴阳规则或出战引用保护失效");
	PETD->set_active_pet(player,"none");
	player->set_vip_flag(0);
	player->set_vip_end_time(0);
	mapping pre_failure = PETD->query_pet_state(player);
	mapping failure = PETD->test_fuse_pets(player,(string)dangkang["id"],
		(string)bifang["id"],0,2,0);
	mapping after_failure = PETD->query_pet_state(player);
	check("合成失败只消耗灵印、完整保留两只原宠并增加失败积累",
		failure["ok"] && !failure["success"] &&
		sizeof((array)after_failure["pets"])==3 &&
		(int)after_failure["materials"]["spirit_mark"]==
			(int)pre_failure["materials"]["spirit_mark"]-10 &&
		(int)after_failure["fusion_pity"]==1,
		"失败路径误删宠物、材料账不平或保底未增加");
	player->set_vip_flag(3);
	player->set_vip_end_time(time()+3600);
	mapping vip_before = PETD->query_pet_state(player);
	mapping vip_failure = PETD->test_fuse_pets(player,
		(string)dangkang["id"],(string)bifang["id"],0,3,1);
	mapping vip_after = PETD->query_pet_state(player);
	check("VIP3只提供失败灵印保护，不改变宠物和成功率",
		vip_failure["ok"] && !vip_failure["success"] &&
		(int)vip_after["materials"]["spirit_mark"]==
			(int)vip_before["materials"]["spirit_mark"]-5 &&
		sizeof((array)vip_after["pets"])==3 &&
		(int)vip_after["fusion_pity"]==2,
		"VIP失败保护影响战斗属性、成功结果或返还数量错误");
	for(int i=0;i<3;i++)
		PETD->test_fuse_pets(player,(string)dangkang["id"],
			(string)bifang["id"],0,3,i%2);
	mapping pity_state = PETD->query_pet_state(player);
	mapping pity_preview = PETD->query_pet_fusion_preview(player,
		(string)dangkang["id"],(string)bifang["id"]);
	check("连续失败五次后的下一次阴阳合成为100%保底",
		(int)pity_state["fusion_pity"]==5 &&
		pity_preview["ok"] &&
		(int)pity_preview["success_chance"]==100,
		"失败积累封顶后仍可能无限连续失败");
	mapping success_before = PETD->query_pet_state(player);
	mapping success = PETD->test_fuse_pets(player,(string)dangkang["id"],
		(string)bifang["id"],1,4,1);
	mapping success_after = PETD->query_pet_state(player);
	mapping child = mappingp(success["pet"]) ? success["pet"] : ([]);
	check("成功合成原子消耗两宠生成一只唯一随机结构宠并继承成长",
		success["ok"] && success["success"] &&
		sizeof((array)success_after["pets"])==2 &&
		find_pet_species(success_after,"dangkang")["id"]!=dangkang["id"] &&
		find_pet_species(success_after,"bifang")["id"]!=bifang["id"] &&
		mappingp(child["fusion"]) &&
		(int)child["fusion"]["quality"]==4 &&
		(string)child["fusion"]["polarity"]=="yang" &&
		(int)child["level"]>=1 && (int)success_after["fusion_pity"]==0 &&
		(int)success_after["materials"]["spirit_mark"]==
			(int)success_before["materials"]["spirit_mark"]-10,
		"成功路径数量、旧ID删除、随机结构或继承字段错误");
	mapping duplicate_attempt = PETD->test_fuse_pets(player,
		(string)dangkang["id"],(string)bifang["id"],1,4,1);
	mapping duplicate_state = PETD->query_pet_state(player);
	PETD->drop_test_pet_cache(player->query_account_owner());
	mapping disk_state = PETD->query_pet_state(player);
	check("旧宠ID不能二次消费且融合宠原子落盘后可完整恢复",
		!duplicate_attempt["ok"] &&
		sizeof((array)duplicate_state["pets"])==2 &&
		disk_state["ok"] && sizeof((array)disk_state["pets"])==2 &&
		mappingp(find_pet_species(disk_state,(string)child["species"])["fusion"]),
		"重复合成产生克隆、材料重复扣除或融合档案无法恢复");
}

void test_rift(array(object) players)
{
	werror("\n【万灵测试】3—5人万灵裂隙\n");
	foreach(players,object player){
		player->move(test_room);
		player->set_term("noterm");
	}
	test_team_id = TERMD->term_create(players[0]->query_name());
	TERMD->add_termer(test_team_id,players[1]->query_name(),
		players[1]->query_name_cn());
	mapping too_few = PETD->start_rift(players[0]);
	TERMD->add_termer(test_team_id,players[2]->query_name(),
		players[2]->query_name_cn());
	mapping started = PETD->start_rift(players[0]);
	mapping won = run_rift(players,1);
	check("裂隙拒绝两人凑数且三名不同账号玩家可在12轮内协作完成",
		!too_few["ok"] && started["ok"] && won["ok"] &&
		won["status"]=="won" && (int)won["round"]<=12,
		"人数门槛、回合上限或正确机制结算失败");

	mapping before0 = PETD->query_pet_state(players[0]);
	int queued_before_restart = sizeof((mapping)before0[
		"pending_rift_rewards"]);
	PETD->drop_test_rift_runtime(players[0]->query_account_owner());
	mapping recovered_pending = PETD->query_rift_state(players[0]);
	mapping claim0 = PETD->claim_rift_reward(players[0],0,0);
	mapping duplicate_claim = PETD->claim_rift_reward(players[0],0,0);
	mapping claim1 = PETD->claim_rift_reward(players[1],9999,9999);
	mapping claim2 = PETD->claim_rift_reward(players[2],9999,9999);
	mapping after0 = PETD->query_pet_state(players[0]);
	check("裂隙胜利资格持久化，模拟Pike重启后仍可个人领取",
		queued_before_restart==1 && recovered_pending["ok"] &&
		recovered_pending["pending"] && recovered_pending["status"]=="won",
		"胜利只保存在运行时，重启会丢失未领取奖励");
	check("裂隙个人奖励重复点击不重复发放，稀有灵卵与异色可测试",
		claim0["ok"] && !duplicate_claim["ok"] && claim1["ok"] &&
		claim2["ok"] &&
		(int)after0["materials"]["spirit_mark"]==
			(int)before0["materials"]["spirit_mark"]+5 &&
		mappingp(claim0["pet_acquisition"]) && claim0["cosmetic"]==1,
		"奖励非个人、幂等凭据失效或低概率契约路径不可验证");

	for(int run=1;run<3;run++){
		mapping next_start = PETD->start_rift(players[0]);
		mapping next_won = run_rift(players,1);
		for(int i=0;i<sizeof(players);i++)
			PETD->claim_rift_reward(players[i],9999,9999);
		check("周目标第"+(run+1)+"场可在上一场全员领取后立即重开",
			next_start["ok"] && next_won["status"]=="won",
			"运行时场次未清理或队伍无法重复挑战");
	}
	mapping weekly_before = PETD->query_pet_state(players[0]);
	mapping weekly = PETD->claim_pet_weekly_choice(players[0],"rune");
	mapping weekly_repeat = PETD->claim_pet_weekly_choice(players[0],"rune");
	check("每周3胜后奖励三选一且一个账号每周只能领取一次",
		(int)weekly_before["weekly"]["rift_wins"]==3 && weekly["ok"] &&
		!weekly_repeat["ok"],"周胜场或三选一幂等限制错误");

	mapping bad_start = PETD->start_rift(players[0]);
	mapping lost = run_rift(players,0);
	mapping restart = PETD->start_rift(players[0]);
	check("缚灵不能靠普通输出绕过且失败场次最多12轮后可立即重开",
		bad_start["ok"] && lost["status"]=="lost" &&
		(int)lost["round"]<=12 && restart["ok"] &&
		restart["session"]["status"]=="active",
		"错误行动仍赢得裂隙、无限等待或失败后无法重开");
	object away_room = clone(ROOT+"/gamelib/d/wanling/wanlingtai");
	players[2]->move(away_room);
	mapping dropout = PETD->query_rift_state(players[0]);
	players[2]->move(test_room);
	mapping rejoined = PETD->start_rift(players[0]);
	check("队员掉线或离房导致有效人数低于3时不再永久卡住队伍",
		dropout["status"]=="lost" && rejoined["ok"] &&
		rejoined["session"]["status"]=="active",
		"失联成员仍占等待位或重新集合后无法重开");
	if(away_room) destruct(away_room);
	// 清掉测试中的未完成重开场次，并重建干净队伍供后续测试。
	foreach(players,object player)
		PETD->remove_test_pet_data(player->query_account_owner());
	if(test_team_id!="" && sizeof(test_team_id)>1)
		TERMD->destory_term(test_team_id,players[0]->query_name());
	test_team_id = "";
}

void test_rift_same_account_rejection(object independent)
{
	string account_id = "xd99testunitpetriftsame";
	object root_player = create_test_player(account_id,"human","jianxian");
	root_player->level = 50;
	root_player->set_att_by_level();
	root_player->save_with_result();
	mapping created = ACCOUNT_CHARACTERD->create_character(
		account_id,"third","fangshi");
	object child = created["ok"] ? restore_child_player(
		(string)created["character"]["id"],"third","fangshi") : 0;
	PETD->choose_starter_pet(root_player,"dangkang");
	root_player->move(test_room);
	if(child) child->move(test_room);
	independent->move(test_room);
	root_player->set_term("noterm");
	if(child) child->set_term("noterm");
	independent->set_term("noterm");
	string team_id = TERMD->term_create(root_player->query_name());
	if(child)
		TERMD->add_termer(team_id,child->query_name(),child->query_name_cn());
	TERMD->add_termer(team_id,independent->query_name(),
		independent->query_name_cn());
	mapping rejected = PETD->start_rift(root_player);
	check("同一注册账号的多个职业不能给裂隙虚增有效人数",
		created["ok"] && child && !rejected["ok"],
		"同账号小号可互刷多人裂隙");
	if(sizeof(team_id)>1)
		TERMD->destory_term(team_id,root_player->query_name());
}

void test_duel(object challenger,object target)
{
	werror("\n【万灵测试】标准化三宠论道\n");
	challenger->move(test_room);
	target->move(test_room);
	challenger->set_term("noterm");
	target->set_term("noterm");
	mapping before_left = PETD->query_pet_state(challenger);
	mapping before_right = PETD->query_pet_state(target);
	int left_life = challenger->get_cur_life();
	int right_life = target->get_cur_life();
	int left_items = sizeof(challenger->packaged_items);
	int right_items = sizeof(target->packaged_items);
	mapping invited = PETD->invite_pet_duel(challenger,target->query_name());
	mapping accepted = invited["ok"] ? PETD->accept_pet_duel(target,
		challenger->query_name(),(string)invited["token"]) : ([]);
	mapping after_left = PETD->query_pet_state(challenger);
	mapping after_right = PETD->query_pet_state(target);
	int left_delta = (int)after_left["materials"]["spirit_mark"]-
		(int)before_left["materials"]["spirit_mark"];
	int right_delta = (int)after_right["materials"]["spirit_mark"]-
		(int)before_right["materials"]["spirit_mark"];
	int match_winner = accepted["ok"] ? (int)accepted["match"]["winner"] : -1;
	int expected_total_reward = match_winner==0 ? 10 : 11;
	int rounds_ok = 1;
	if(accepted["ok"])
		foreach((array)accepted["match"]["bouts"],mapping bout)
			rounds_ok = rounds_ok && (int)bout["rounds"]<=12;
	check("论道真实走邀请令牌、三局两胜和单局12回合上限",
		invited["ok"] && is_hex_pet_id((string)invited["token"]) &&
		accepted["ok"] && sizeof((array)accepted["match"]["bouts"])==3 &&
		rounds_ok,"邀请令牌、标准化编队或回合上限错误");
	check("首次不同对手胜方6/参与方5、平局各5且不改变人物战斗资产",
		left_delta+right_delta==expected_total_reward &&
		left_delta>=5 && left_delta<=6 &&
		right_delta>=5 && right_delta<=6 &&
		challenger->get_cur_life()==left_life && target->get_cur_life()==right_life &&
		sizeof(challenger->packaged_items)==left_items &&
		sizeof(target->packaged_items)==right_items &&
		!challenger->in_combat && !target->in_combat,
		"论道奖励差超过20%或修改了人物生命、背包、战斗状态");
	mapping repeat_invite = PETD->invite_pet_duel(challenger,target->query_name());
	mapping repeat = repeat_invite["ok"] ? PETD->accept_pet_duel(target,
		challenger->query_name(),(string)repeat_invite["token"]) : ([]);
	mapping repeat_left = PETD->query_pet_state(challenger);
	mapping repeat_right = PETD->query_pet_state(target);
	check("当天重复同一注册账号对手仍可切磋但双方不再获利",
		repeat["ok"] && !repeat["challenger_rewarded"] &&
		!repeat["target_rewarded"] &&
		repeat_left["materials"]["spirit_mark"]==
			after_left["materials"]["spirit_mark"] &&
		repeat_right["materials"]["spirit_mark"]==
			after_right["materials"]["spirit_mark"],
		"重复对手仍可刷取灵印");
	mapping simulated = PETD->test_simulate_pet_match("dangkang","bifang");
	check("纯模拟论道始终返回三场确定性结果且无需人物对象",
		sizeof((array)simulated["bouts"])==3,
		"标准化模拟器依赖人物装备或运行时战斗对象");
}

void test_corruption_and_wiring()
{
	werror("\n【万灵测试】损坏保护、命令接线与旧系统隔离\n");
	string account_id = "xd99testunitpetbad";
	object player = create_test_player(account_id,"third","lingyi");
	player->level = 50;
	player->set_att_by_level();
	PETD->choose_starter_pet(player,"lushu");
	string path = pet_file(account_id);
	string valid_source = Stdio.read_file(path);
	Stdio.write_file(path+".bak",valid_source);
	Stdio.write_file(path,"{broken");
	PETD->drop_test_pet_cache(account_id);
	mapping corrupt = PETD->query_pet_state(player);
	check("宠物主文件损坏时失败关闭且不会用旧备份复活状态",
		valid_source && !corrupt["ok"],
		"损坏文件被静默重建或过期备份成为权威数据");
	Stdio.write_file(path,valid_source);
	rm(path+".bak");
	PETD->drop_test_pet_cache(account_id);

	array(string) commands = ({
		"pet","daily_cultivation","pet_hunt","wanling_join",
		"wanling_rift","pet_duel","sell_equipment_batch",
	});
	int compile_ok = 1;
	foreach(commands,string command){
		mixed err = catch {
			object cmd = (object)(ROOT+"/gamelib/cmds/"+command+".pike");
			compile_ok = compile_ok && !!cmd;
		};
		if(err) compile_ok = 0;
	}
	object|zero room_program = 0;
	mixed room_err = catch {
		room_program = (object)(ROOT+"/gamelib/d/wanling/wanlingtai");
	};
	object httpd = (object)(ROOT+
		"/gamelib/single/daemons/http_api_daemon.pike");
	check("宠物、批量卖装命令、万灵台和HTTP核心串行路由全部接通",
		compile_ok && !room_err && room_program && httpd &&
		httpd->is_core_command("pet choose dangkang")==1 &&
		httpd->is_core_command("wanling_rift action break")==1 &&
		httpd->is_core_command("pet_duel invite someone")==1,
		"命令/房间编译失败或写操作被错误放入工作线程");

	string pet_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/petd.pike");
	string pet_modules = "";
	foreach(get_dir(ROOT+"/gamelib/single/daemons/_pet_mod") || ({}),
		string module)
		if(has_suffix(module,".pike"))
			pet_modules += Stdio.read_file(ROOT+
				"/gamelib/single/daemons/_pet_mod/"+module) || "";
	string dog_source = Stdio.read_file(ROOT+"/gamelib/cmds/home_mydog.pike");
	string home_source = Stdio.read_file(ROOT+
		"/gamelib/cmds/home_buy_dog_detail.pike");
	string user_source = Stdio.read_file(ROOT+"/gamelib/clone/user.pike");
	string vue_source = Stdio.read_file(ROOT+"/vue_source/index.html");
	check("通用灵宠不克隆NPC、不登记SUMMOND且旧家园守宅犬数据零迁移",
		pet_source && search(pet_modules,"clone(")==-1 &&
		search(pet_modules,"register_summon")==-1 &&
		dog_source && home_source && search(dog_source,"PETD")==-1 &&
		search(home_source,"PETD")==-1,
		"万灵系统与方士召唤槽或旧家园犬产生数据耦合");
	check("旧文字入口与Vue快捷入口均能发现万灵谱",
		user_source && search(user_source,"[万灵:pet]")!=-1 &&
		vue_source && search(vue_source,"sendQuickCommand('pet')")!=-1,
		"至少一个客户端没有万灵入口");
}

void cleanup_all()
{
	if(original_player)
		set_this_player(original_player);
	else
		set_this_player(this_object());
	if(test_team_id!="" && sizeof(test_team_id)>1 && sizeof(test_players))
		catch(TERMD->destory_term(test_team_id,test_players[0]->query_name()));
	foreach(test_players,object player)
		if(player) catch(destruct(player));
	test_players = ({});
	if(test_room) catch(destruct(test_room));
	test_room = 0;
	foreach(test_accounts,string account_id)
		cleanup_account(account_id);
	test_accounts = ({});
}

int main()
{
	original_player = this_player();
	werror("\n========== 山海万灵系统完整测试 ==========\n");
	array(array(string)) professions = ({
		({"human","jianxian"}),({"human","yushi"}),
		({"human","zhuxian"}),({"monst","kuangyao"}),
		({"monst","wuyao"}),({"monst","yinggui"}),
		({"third","fangshi"}),({"third","zhenyue"}),
		({"third","tianxiang"}),({"third","lingyi"}),
	});
	array(object) profession_players = ({});
	string error_desc = "";
	mixed err = catch {
		test_room = clone(ROOT+"/gamelib/d/wanling/wanlingtai");
		for(int i=0;i<sizeof(professions);i++){
			string userid = "xd99testunitpet"+(i<10 ? "0" : "")+i;
			profession_players += ({create_test_player(userid,
				professions[i][0],professions[i][1])});
		}
		int players_ok = sizeof(profession_players)==10;
		foreach(profession_players,object player)
			players_ok = players_ok && !!player;
		check("测试环境建立十职业人物与中立万灵台",players_ok && !!test_room,
			"测试人物或房间创建失败");
		if(players_ok && test_room){
			test_catalog_and_all_professions(profession_players);
			test_collection_growth(profession_players[0]);
			test_legacy_pet_migration();
			 test_same_account_active_pet();
			test_hunt_and_assist(profession_players[0],profession_players[1]);
			test_solo_pve_fragment_channels();
			test_pet_batch_growth_and_fusion();
			test_rift(profession_players[0..2]);
			// 上一项特意清理了前三个账号的宠物数据；重新初契供反刷和论道。
			for(int i=0;i<3;i++){
				PETD->drop_test_pet_cache(profession_players[i]->query_name());
				PETD->choose_starter_pet(profession_players[i],
					PETD->query_starter_species()[i]);
			}
			test_rift_same_account_rejection(profession_players[2]);
			test_duel(profession_players[0],profession_players[1]);
			test_corruption_and_wiring();
		}
	};
	if(err){
		error_desc = describe_error(err);
		check("测试脚本自身无未捕获异常",0,error_desc);
	}
	cleanup_all();
	werror("\n山海万灵测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
