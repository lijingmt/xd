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
	// 真实登录会在恢复档案后注册living identity；只调
	// restore()会让组队守护进程正确地把该测试角色判为离线。
	if(!player->setup("testunit88")){
		destruct(player);
		return 0;
	}
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
	int valid_catalog = sizeof(catalog)==16 && sizeof(starters)==3 &&
		sizeof(bosses)==5;
	foreach(catalog;string species;mapping info)
		valid_catalog = valid_catalog && sizeof((array)info["skill_sets"])==3 &&
			sizeof((array)info["skill_sets"][0])==3 &&
			(string)info["name"]!="" && (string)info["origin"]!="";
	valid_catalog = valid_catalog && (int)catalog["luanniao"]["hidden"]==1 &&
		(string)catalog["luanniao"]["skill"]=="回生羽";
	check("15种公开异兽、1只隐藏鸾鸟、3只初契与5只轮替首领完整",
		valid_catalog,"图鉴数量、文化小传或灵纹配置不完整");

	object first = players[0];
	mapping read_only = PETD->query_pet_state(first);
	mapping early_guide = PETD->query_pet_growth_guidance(first);
	mapping too_early = PETD->choose_starter_pet(first,"dangkang");
	check("旧账号读取与14级误点都不创建宠物附属文件",
		read_only["ok"] && !too_early["ok"] &&
		Stdio.file_size(pet_file(first->query_name()))<=0,
		"只读兼容路径写盘或提前领取成功");
	check("成长助手在初契开放前只推荐安全升级路径",
		early_guide["ok"] &&
		sizeof((array)early_guide["suggestions"])==1 &&
		(string)early_guide["suggestions"][0]["phase"]=="初契" &&
		(string)early_guide["suggestions"][0]["action_command"]==
			"autofight open",
		"未到15级时误导玩家领取或建议没有直达挂机设置");

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
	mapping starter_guide = PETD->query_pet_growth_guidance(first);
	check("初契后成长助手优先每日寻迹且最多返回三项只读建议",
		starter_guide["ok"] &&
		sizeof((array)starter_guide["suggestions"])>=1 &&
		sizeof((array)starter_guide["suggestions"])<=3 &&
		(string)starter_guide["suggestions"][0]["action_command"]==
			"pet_hunt" &&
		(int)PETD->query_pet_state(first)["daily"]["hunt"]==0,
		"助手排序错误、建议过多或只读查询意外启动了寻迹");
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
	mapping no_rune_reset = PETD->reset_pet_skills(player,pet_id);
	mapping no_rune_state = PETD->query_pet_state(player);
	check("灵纹符不足时明确显示零枚、独立材料栏和每周领取路径",
		!no_rune_reset["ok"] &&
		search((string)no_rune_reset["message"],"当前有0枚")!=-1 &&
		search((string)no_rune_reset["message"],"不进入人物背包")!=-1 &&
		search((string)no_rune_reset["message"],"本周目标")!=-1 &&
		(int)no_rune_state["materials"]["skill_rune"]==0,
		(string)no_rune_reset["message"]);

	PETD->test_add_pet_material(player,"spirit_dew",1000);
	PETD->test_add_pet_material(player,"bond_token",20);
	PETD->test_add_pet_material(player,"skill_rune",3);
	int growth_ok = 1;
	for(int i=1;i<50;i++)
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
	check("培养严格封顶当前人物50级、十星、五阶羁绊且三套灵纹确定轮换",
		growth_ok && !level_reject["ok"] && !star_reject["ok"] &&
		!bond_reject["ok"] &&
		(int)grown["pets"][0]["level"]==50 &&
		(int)grown["pets"][0]["trained_level"]==50 &&
		(int)grown["pets"][0]["level_max"]==50 &&
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
		(int)grown["pets"][0]["growth_percent"]==217 &&
		(int)grown["pets"][0]["pvp_growth_percent"]==123,
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

void test_pet_player_level_cap()
{
	werror("\n【万灵测试】人物等级联动与共享进度保留\n");
	object player = create_test_player("xd99testunitpetlevelcap","human",
		"jianxian");
	player->level = 15;
	player->set_att_by_level();
	mapping chosen = PETD->choose_starter_pet(player,"dangkang");
	mapping state = PETD->query_pet_state(player);
	string pet_id = sizeof((array)state["pets"]) ?
		(string)state["pets"][0]["id"] : "";
	PETD->test_add_pet_material(player,"spirit_dew",1000);
	int trained = 1;
	for(int i=1;i<15;i++)
		trained = trained && PETD->train_pet_level(player,pet_id)["ok"];
	mapping capped = PETD->query_pet_state(player);
	int dew_at_cap = (int)capped["materials"]["spirit_dew"];
	mapping cap_reject = PETD->train_pet_level(player,pet_id);
	mapping after_reject = PETD->query_pet_state(player);
	check("共享宠物不能超过当前人物等级且拒绝时不扣灵露",
		chosen["ok"] && trained && !cap_reject["ok"] &&
		(int)capped["pets"][0]["level"]==15 &&
		(int)capped["pets"][0]["trained_level"]==15 &&
		(int)capped["pets"][0]["level_max"]==15 &&
		(int)after_reject["materials"]["spirit_dew"]==dew_at_cap,
		"人物等级上限、拒绝返回或材料事务有误");
	player->level = 16;
	player->set_att_by_level();
	mapping resumed = PETD->train_pet_level(player,pet_id);
	player->level = 10;
	player->set_att_by_level();
	mapping limited = PETD->query_pet_state(player);
	mapping limited_presence = PETD->query_pet_battle_presence(player);
	int dew_before_low_reject = (int)limited["materials"]["spirit_dew"];
	mapping low_reject = PETD->train_pet_level(player,pet_id);
	mapping low_after = PETD->query_pet_state(player);
	check("低等级角色不破坏共享高等级进度，战斗运行态自动软限制",
		resumed["ok"] && (int)limited["pets"][0]["level"]==10 &&
		(int)limited["pets"][0]["trained_level"]==16 &&
		(int)limited["pets"][0]["level_limited"]==1 &&
		(int)limited_presence["level"]==10 && !low_reject["ok"] &&
		(int)low_after["pets"][0]["trained_level"]==16 &&
		(int)low_after["materials"]["spirit_dew"]==dew_before_low_reject,
		"软限制破坏共享存档、协战运行态或材料账");
	player->level = 17;
	player->set_att_by_level();
	mapping unlocked_presence = PETD->query_pet_battle_presence(player);
	mapping continued = PETD->train_pet_level(player,pet_id);
	mapping final_state = PETD->query_pet_state(player);
	check("人物再升级后自动解锁已保留进度并可继续培养",
		(int)unlocked_presence["level"]==16 && continued["ok"] &&
		(int)final_state["pets"][0]["level"]==17 &&
		(int)final_state["pets"][0]["trained_level"]==17 &&
		!(int)final_state["pets"][0]["level_limited"],
		"角色升级后运行态未刷新或培养仍被错误拦截");
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
		(int)migrated["version"]==4 &&
		(int)migrated["pets"][0]["star"]==1 &&
		(int)disk_after_read["version"]==1 &&
		!has_index(disk_after_read["pets"][0],"star"),
		"旧档案无法读取、星级不是安全默认值或查看触发了批量迁移");
	check("旧档案下一次真实修改通过原子保存自然升级为V4",
		mutation && (int)disk_after_write["version"]==4 &&
		(int)disk_after_write["pets"][0]["star"]==1,
		"V1内存迁移后无法保存或永久星级字段丢失");
	// 生产中的V3档案已经包含宠物装备与灵技拓印，V4迁移只能补新字段，
	// 不能像V1/V2迁移那样重建装备栏。
	mapping legacy_v3 = copy_value(disk_after_write);
	legacy_v3["version"] = 3;
	m_delete(legacy_v3,"hidden_luan_pity");
	m_delete(legacy_v3["daily"],"owner_revive");
	string gear_before_v3 = Standards.JSON.encode(
		legacy_v3["gear_inventory"]);
	Stdio.write_file(path,Standards.JSON.encode(legacy_v3));
	rm(path+".bak");
	PETD->drop_test_pet_cache(account_id);
	mapping migrated_v3 = PETD->query_pet_state(player);
	mapping disk_after_v3_read = Standards.JSON.decode(
		Stdio.read_file(path));
	int v3_mutation = PETD->test_add_pet_material(player,"spirit_dew",1);
	mapping disk_after_v3_write = Standards.JSON.decode(
		Stdio.read_file(path));
	check("V3装备档案只读迁移到V4时完整保留装备且下一次修改才落盘",
		migrated_v3["ok"] && (int)migrated_v3["version"]==4 &&
		(int)disk_after_v3_read["version"]==3 && v3_mutation &&
		(int)disk_after_v3_write["version"]==4 &&
		Standards.JSON.encode(disk_after_v3_write["gear_inventory"])==
			gear_before_v3 &&
		(int)disk_after_v3_write["daily"]["owner_revive"]==0 &&
		(int)disk_after_v3_write["hidden_luan_pity"]==0,
		"升级V4时提前写盘、清空V3装备或遗漏新字段");
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
	mapping header_state = HTTP_APID->query_player_state(player);
	int expected_max = player->query_life_max()*2/100*
		(int)presence["growth_percent"]/100/2;
	check("疗愈伙伴30秒低频触发并遵循现有减疗上限规则",
		assist["ok"] && assist["type"]=="heal" &&
		(int)assist["amount"]>0 && (int)assist["amount"]<=expected_max &&
		!cooldown["ok"] && first->get_cur_life()==npc_before &&
		player->get_cur_life()>life_before,
		"协战忽略冷却、减疗或错误修改NPC生命");
	check("协战事件向战斗小窗和Header提供宠物、技能与唯一事件编号",
		presence["active"] && presence["name"]=="当康" &&
		presence["icon"]!="" && presence["skill"]=="丰穰守心" &&
		(int)presence["level"]==50 && (int)presence["star"]==10 &&
		presence["evolution_name"]=="真形·圆满" &&
		(int)presence["power"]>0 && presence["combat_mode"]=="pve" &&
		(int)presence["cooldown_remaining"]>0 &&
		(int)presence["cooldown_remaining"]<=30 &&
		mappingp(presence["recent_event"]) &&
		(string)presence["recent_event"]["id"]!="" &&
		presence["recent_event"]["type"]=="heal" &&
		presence["recent_event"]["mode"]=="pve" &&
		(int)presence["recent_event"]["amount"]==(int)assist["amount"] &&
		mappingp(header_state["pet_assist"]) &&
		header_state["pet_assist"]["active"] &&
		header_state["pet_assist"]["name"]=="当康" &&
		(int)header_state["pet_assist"]["star"]==10,
		"状态API无法可靠渲染Header随行卡片或战斗协战动画");
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
	player->set_life(player->query_life_max());
	mapping pvp_waiting = ([]);
	for(int round=1;round<=5;round++)
		pvp_waiting = PETD->perform_pet_combat_assist(player,pvp_target);
	mapping pvp_wait_presence = PETD->query_pet_battle_presence(player);
	check("PVP治疗充能就绪但主人满血时不吞协战次数并保留满充能",
		!pvp_waiting["ok"] && pvp_waiting["waiting_resource"]=="life" &&
		(int)pvp_wait_presence["pvp_uses"]==1 &&
		(int)pvp_wait_presence["pvp_charge"]==
			(int)pvp_wait_presence["pvp_charge_required"] &&
		pvp_wait_presence["waiting_resource"]=="life",
		"满生命零治疗仍消耗PVP次数、清空充能或缺少就绪状态");
	player->set_life(player->query_life_max()/2);
	mapping second_pvp = PETD->perform_pet_combat_assist(player,pvp_target);
	mapping exhausted = PETD->perform_pet_combat_assist(player,pvp_target);
	check("资源出现缺口后立即释放已就绪灵技且每场仍最多触发两次",
		second_pvp["ok"] && (int)second_pvp["amount"]>0 &&
		!exhausted["ok"] &&
		(int)PETD->query_pet_battle_presence(player)["pvp_uses"]==2,
		"等待资源后重新充能、重复消耗次数或可绕过每场两次限制");
	if(player->query_in_combat())
		player->_clean_fight();
	if(pvp_target->query_in_combat())
		pvp_target->_clean_fight();
	player->set_life(player->query_life_max());
	player["/tmp/wanling/assist_at"] = 0;
	mapping before_full_life = PETD->query_pet_battle_presence(player);
	string before_full_event = mappingp(before_full_life["recent_event"]) ?
		(string)before_full_life["recent_event"]["id"] : "";
	mapping full_life_assist = PETD->perform_pet_pve_assist(player,first);
	mapping full_life_presence = PETD->query_pet_battle_presence(player);
	check("PVE治疗就绪但主人满血时不吞冷却也不生成零值伪事件",
		!full_life_assist["ok"] &&
		full_life_assist["waiting_resource"]=="life" &&
		(int)player["/tmp/wanling/assist_at"]==0 &&
		full_life_presence["waiting_resource"]=="life" &&
		(mappingp(full_life_presence["recent_event"]) ?
			(string)full_life_presence["recent_event"]["id"] : "")==
			before_full_event,
		"满生命零治疗仍进入冷却或伪造了一次灵技触发");
	player->set_life(player->query_life_max()/2);
	mapping ready_heal = PETD->perform_pet_pve_assist(player,first);
	check("主人受伤后无需重新等待即可释放已就绪PVE治疗",
		ready_heal["ok"] && ready_heal["type"]=="heal" &&
		(int)ready_heal["amount"]>0 &&
		(int)player["/tmp/wanling/assist_at"]>0,
		"资源出现缺口后治疗仍不生效或错误重算冷却");
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

void test_pet_auto_combat_growth()
{
	werror("\n【万灵测试】真实战斗历练自动连续升级\n");
	object player = create_test_player("xd99testunitpetxp","third",
		"fangshi");
	player->level = 50;
	player->set_att_by_level();
	PETD->choose_starter_pet(player,"dangkang");
	object normal = make_npc(player,50);
	mapping first = PETD->record_pet_combat_xp(player,normal);
	mapping repeated = PETD->record_pet_combat_xp(player,normal);
	object low = make_npc(player,44);
	mapping low_gain = PETD->record_pet_combat_xp(player,low);
	mapping after_normal = PETD->query_pet_state(player);
	check("同级真实怪提供独立历练且同一死亡、低六级怪不能重复刷",
		first["ok"] && (int)first["xp_gain"]==65 &&
		!repeated["ok"] && !low_gain["ok"] &&
		(int)after_normal["pets"][0]["level"]==1 &&
		(int)after_normal["pets"][0]["xp"]==65 &&
		(int)after_normal["pets"][0]["xp_need"]==125,
		"历练公式、同怪去重、等级差限制或进度视图错误");
	player->_fight(normal);
	normal->_fight(player);
	mapping combat_guide = PETD->query_pet_growth_guidance(player);
	player->_clean_fight();
	normal->_clean_fight();
	check("交战中的成长助手只建议查看战况且不诱导非法培养",
		combat_guide["ok"] &&
		sizeof((array)combat_guide["suggestions"])==1 &&
		(string)combat_guide["suggestions"][0]["phase"]=="协战" &&
		(string)combat_guide["suggestions"][0]["action_command"]=="attack" &&
		(int)PETD->query_pet_state(player)["pets"][0]["xp"]==65,
		"交战时仍推荐换宠、培养或只读查询改变了历练");

	player->fb_id = "testunit/pet_xp";
	FBD->add_fb_members(player->fb_id,player->query_name());
	object dungeon_boss = make_npc(player,55);
	dungeon_boss->_boss = 1;
	mapping boss_gain = PETD->record_pet_combat_xp(player,dungeon_boss);
	FBD->delete_fb_members(player->fb_id,player->query_name());
	player->fb_id = "";
	mapping grown = PETD->query_pet_state(player);
	PETD->drop_test_pet_cache(player->query_name());
	mapping restored = PETD->query_pet_state(player);
	check("副本首领历练可一次连续升级并同步当前协战运行时",
		boss_gain["ok"] && (int)boss_gain["xp_gain"]==282 &&
		(int)boss_gain["levels_gained"]==2 &&
		(int)grown["pets"][0]["level"]==3 &&
		(int)grown["pets"][0]["xp"]==72 &&
		(int)grown["pets"][0]["xp_need"]==175 &&
		(int)player["/tmp/wanling/pet_level"]==3,
		"首领/副本加成、连续扣除阈值或运行时属性未同步");
	check("自动成长通过账号万灵谱原子保存且重载后进度不回档",
		restored["ok"] && (int)restored["pets"][0]["level"]==3 &&
		(int)restored["pets"][0]["xp"]==72 &&
		(int)restored["pets"][0]["xp_progress_percent"]==41,
		"等级或剩余历练只在内存生效、重载后丢失");
	foreach(({normal,low,dungeon_boss}),object npc)
		if(npc) destruct(npc);
}

void test_pet_equipment_and_skill_imprint()
{
	werror("\n【万灵测试】灵宠三槽装备与主人技能拓印\n");
	object player = create_test_player("xd99testunitpetgear","third",
		"lingyi");
	player->level = 50;
	player->set_att_by_level();
	array inventory_before = copy_value(player->packaged_items);
	mapping chosen = PETD->choose_starter_pet(player,"wenyaoyu");
	mapping state = PETD->query_pet_state(player);
	mapping pet = find_pet_species(state,"wenyaoyu");
	string pet_id = (string)pet["id"];
	mapping gear_state = PETD->query_pet_equipment_state(player,pet_id);
	check("初契自动建立并穿戴兽铠、灵饰、灵核且不占人物背包",
		chosen["ok"] && gear_state["ok"] &&
		sizeof((array)gear_state["gear_inventory"])==3 &&
		sizeof((mapping)gear_state["pet"]["equipment_details"])==3 &&
		(int)gear_state["pet"]["equipment_bonus"]["life"]==2 &&
		(int)gear_state["pet"]["equipment_bonus"]["attack"]==2 &&
		(int)gear_state["pet"]["equipment_bonus"]["spirit"]==3 &&
		player->packaged_items==inventory_before,
		"初契装备缺槽、派生属性错误或污染人物背包");

	player->skills["huichun"] = ({25,0});
	player->skills["wanmuxinchun"] = ({1,0});
	player->skills["xuehailieshang"] = ({1,0});
	player->skills["b_nuhou"] = ({100,0});
	mapping too_early = PETD->imprint_pet_skill(player,pet_id,"huichun");
	PETD->test_add_pet_material(player,"spirit_dew",100);
	int trained = 1;
	for(int level=1;level<20;level++)
		trained = trained && PETD->train_pet_level(player,pet_id)["ok"];
	array candidates = PETD->query_pet_imprint_skill_candidates(player);
	int has_heal = 0;
	int has_wanmu = 0;
	int has_dot = 0;
	int has_injected = 0;
	foreach(candidates,mapping candidate){
		if((string)candidate["name"]=="huichun")
			has_heal = 1;
		if((string)candidate["name"]=="wanmuxinchun" &&
		   (string)candidate["effect"]=="heal")
			has_wanmu = 1;
		if((string)candidate["name"]=="xuehailieshang" &&
		   (string)candidate["effect"]=="dot")
			has_dot = 1;
		if((string)candidate["name"]=="b_nuhou")
			has_injected = 1;
	}
	mapping imprinted = PETD->imprint_pet_skill(player,pet_id,"huichun");
	mapping core_locked = PETD->unequip_pet_gear(player,pet_id,
		"spirit_core");
	check("灵技只接受20级后真实学会的主动技能并拒绝注入技能",
		!too_early["ok"] && trained && has_heal && has_wanmu && has_dot &&
		!has_injected &&
		imprinted["ok"] && !core_locked["ok"],
		"等级、技能来源过滤或承载灵核保护失效");

	player->move(test_room);
	player->set_life(player->query_life_max()/2);
	player["/tmp/wanling/assist_at"] = 0;
	object npc = make_npc(player,50);
	int life_before = player->get_cur_life();
	mapping assist = PETD->perform_pet_pve_assist(player,npc);
	mapping presence = PETD->query_pet_battle_presence(player);
	check("灵息型文鳐鱼拓印回春后按宠物安全公式治疗且显示拓印技能",
		assist["ok"] && assist["type"]=="heal" &&
		(int)assist["amount"]>0 && player->get_cur_life()>life_before &&
		search((string)presence["skill"],"拓印·")==0 &&
		presence["native_skill"]=="夜渡回澜" &&
		mappingp(presence["imprinted_skill"]),
		"拓印直接沿用原定位、没有治疗或战斗小窗技能名错误");

	PETD->test_add_pet_material(player,"skill_rune",1);
	mapping wanmu_imprinted = PETD->imprint_pet_skill(player,pet_id,
		"wanmuxinchun");
	player->set_life(player->query_life_max());
	player["/tmp/wanling/assist_at"] = 0;
	mapping wanmu_before = PETD->query_pet_battle_presence(player);
	string wanmu_event_before = mappingp(wanmu_before["recent_event"]) ?
		(string)wanmu_before["recent_event"]["id"] : "";
	mapping wanmu_waiting = PETD->perform_pet_pve_assist(player,npc);
	mapping wanmu_wait_presence = PETD->query_pet_battle_presence(player);
	mapping balanced_rhythm = PETD->query_pet_rune_rhythm_profile(0);
	mapping agile_rhythm = PETD->query_pet_rune_rhythm_profile(1);
	mapping charged_rhythm = PETD->query_pet_rune_rhythm_profile(2);
	check("三套灵纹公开说明与真实冷却、倍率和PVP蓄能常量一致",
		balanced_rhythm["effect_percent"]==100 &&
		balanced_rhythm["pve_cooldown"]==30 &&
		balanced_rhythm["pvp_charge"]==
			PETD->query_pet_pvp_charge_required(0) &&
		agile_rhythm["effect_percent"]==80 &&
		agile_rhythm["pve_cooldown"]==24 &&
		agile_rhythm["pvp_charge"]==
			PETD->query_pet_pvp_charge_required(1) &&
		charged_rhythm["effect_percent"]==115 &&
		charged_rhythm["pve_cooldown"]==36 &&
		charged_rhythm["pvp_charge"]==
			PETD->query_pet_pvp_charge_required(2) &&
		search((string)wanmu_wait_presence["rune_effect"],
			"三枚灵纹整套触发")!=-1,
		"灵纹页面说明可能与实际战斗常量漂移或仍无效果描述");
	string pet_command_source = Stdio.read_file(ROOT+
		"/gamelib/cmds/pet.pike") || "";
	check("共享宠物详情逐套解释灵纹效果并提示本命战斗位会暂停触发",
		search(pet_command_source,
			"PETD->query_pet_rune_rhythm_description")!=-1 &&
		search(pet_command_source,"当前战斗位是本命灵伴")!=-1 &&
		search(pet_command_source,"真实生效时战斗中会出现三纹共鸣提示")!=-1,
		"玩家仍需猜灵纹组合效果或无法判断共享宠物为何不出手");
	player->set_life(player->query_life_max()/2);
	int wanmu_life_before = player->get_cur_life();
	player->_fight(npc);
	npc->_fight(player);
	player->heart_beat();
	mapping wanmu_presence = PETD->query_pet_battle_presence(player);
	mapping wanmu_event = mappingp(wanmu_presence["recent_event"]) ?
		wanmu_presence["recent_event"] : ([]);
	check("拓印万木新春经真实人物心跳治疗且满血不吞冷却",
		wanmu_imprinted["ok"] && !wanmu_waiting["ok"] &&
		wanmu_waiting["waiting_resource"]=="life" &&
		(int)wanmu_wait_presence["cooldown_remaining"]==0 &&
		(mappingp(wanmu_wait_presence["recent_event"]) ?
			(string)wanmu_wait_presence["recent_event"]["id"] : "")==
			wanmu_event_before && wanmu_event["type"]=="heal" &&
		(int)wanmu_event["amount"]>0 &&
		player->get_cur_life()>wanmu_life_before &&
		search((string)wanmu_presence["skill"],"万木新春")!=-1 &&
		wanmu_event["skill"]==wanmu_presence["skill"] &&
		wanmu_event["rune_set_triggered"],
		"真实人物心跳未触发万木新春、误判为攻击或事件没有显示灵纹");
	if(player->query_in_combat())
		player->_clean_fight();
	if(npc->query_in_combat())
		npc->_clean_fight();
	int combat_at_before_refresh = (int)player["/tmp/wanling/assist_at"];
	player["/tmp/wanling/pet_skills"] = ({"旧灵纹", "旧灵纹", "旧灵纹"});
	player["/tmp/wanling/imprinted_skill"] = 0;
	PETD->drop_test_pet_cache(player->query_account_owner());
	PETD->mark_pet_player_runtime_stale(player);
	mapping refreshed_presence = PETD->query_pet_battle_presence(player);
	check("Worker账号缓存换代后重建在线人物灵技灵纹且不刷新战斗冷却",
		!(int)player["/tmp/wanling/runtime_stale"] &&
		search((string)refreshed_presence["skill"],"万木新春")!=-1 &&
		search((array)refreshed_presence["runes"],"旧灵纹")==-1 &&
		(int)player["/tmp/wanling/assist_at"]==combat_at_before_refresh,
		"只清账号缓存但在线人物继续使用旧拓印/灵纹，或借刷新重置冷却");

	PETD->test_add_pet_material(player,"skill_rune",1);
	mapping dot_imprinted = PETD->imprint_pet_skill(player,pet_id,
		"xuehailieshang");
	// 更新前的宠物档案把DOT记成damage；即使未重新拓印，
	// 运行时也必须根据真实技能类型恢复持续伤害。
	if(mappingp(player["/tmp/wanling/imprinted_skill"]))
		player["/tmp/wanling/imprinted_skill"]["effect"] = "damage";
	player["/tmp/wanling/assist_at"] = 0;
	npc->set_life(npc->query_life_max());
	int dot_life_before = npc->get_cur_life();
	object dot_skill = MUD_SKILLSD["xuehailieshang"];
	mapping dot_balance = PETD->query_pet_imprinted_dot_profile(
		player,npc,1,"pve");
	int expected_dot_damage = (int)dot_balance["source_tick"]*35*
		(int)dot_balance["rhythm_percent"]/10000;
	if(expected_dot_damage<(int)dot_balance["fallback_tick"])
		expected_dot_damage = (int)dot_balance["fallback_tick"];
	mapping dot_assist = PETD->perform_pet_pve_assist(player,npc);
	int dot_duration = (int)npc->query_debuff("dot",2);
	int dot_damage = (int)npc->query_debuff("dot",1);
	player->drain_catch_tell(0,50);
	player->_fight(npc);
	npc->_fight(player);
	npc->heart_beat();
	string dot_tick_text = player->drain_catch_tell(0,50);
	int dot_life_after_first = npc->get_cur_life();
	npc->heart_beat();
	string dot_second_tick_text = player->drain_catch_tell(0,50);
	check("宠物拓印DOT经真实战斗心跳逐跳扣血并显示伤害与剩余节拍",
		dot_imprinted["ok"] && dot_assist["ok"] &&
		dot_assist["type"]=="dot" && dot_duration==12 &&
		dot_skill && (int)dot_balance["inherit_percent"]==35 &&
		(int)dot_balance["source_tick"]==
			player->query_active_dot_damage(dot_skill,1,npc) &&
		dot_damage==expected_dot_damage &&
		dot_life_after_first==dot_life_before-dot_damage &&
		npc->get_cur_life()==dot_life_before-dot_damage*2 &&
		(int)npc->query_debuff("dot",2)==dot_duration-2 &&
		search(dot_tick_text,"【持续伤害】")!=-1 &&
		search(dot_tick_text,"血海裂伤")!=-1 &&
		search(dot_tick_text,"点持续伤害")!=-1 &&
		search(dot_tick_text,"剩余"+(dot_duration-1)+"个战斗节拍")!=-1 &&
		search(dot_second_tick_text,"【持续伤害】")!=-1 &&
		search(dot_second_tick_text,"剩余"+(dot_duration-2)+
			"个战斗节拍")!=-1,
		sprintf("拓印DOT或心跳失效: imprint=%d assist=%d/%s "+
			"life=%d/%d/%d damage=%d duration=%d/%d text=%O/%O",
			(int)dot_imprinted["ok"],(int)dot_assist["ok"],
			(string)dot_assist["type"],npc->get_cur_life(),
			dot_life_after_first,dot_life_before,
			dot_damage,(int)npc->query_debuff("dot",2),dot_duration,
			dot_tick_text,dot_second_tick_text));

	object dot_boss = make_npc(player,50);
	dot_boss->_boss = 1;
	mapping boss_dot_balance = PETD->query_pet_imprinted_dot_profile(
		player,dot_boss,1,"pve");
	object dot_pvp_target = create_test_player(
		"xd99testunitpetdotpvp","human","zhenyue");
	dot_pvp_target->level = 50;
	dot_pvp_target->set_att_by_level();
	dot_pvp_target->move(test_room);
	mapping pvp_dot_balance = PETD->query_pet_imprinted_dot_profile(
		player,dot_pvp_target,1,"pvp");
	player["/pet_battle/source"] = "shared";
	mapping fast_dot_profile = PETD->query_pet_pk_fast_profile(
		player,dot_pvp_target);
	check("拓印持续伤害按普通35%、首领20%、PVP 15%分层且复用人物公式",
		(int)boss_dot_balance["inherit_percent"]==20 &&
		(int)boss_dot_balance["source_tick"]==
			player->query_active_dot_damage(dot_skill,1,dot_boss) &&
		(int)pvp_dot_balance["inherit_percent"]==15 &&
		(int)pvp_dot_balance["source_tick"]==
			player->query_active_dot_damage(dot_skill,1,dot_pvp_target) &&
		(int)boss_dot_balance["tick_damage"]==
			(int)boss_dot_balance["source_tick"]*20*
			(int)boss_dot_balance["rhythm_percent"]/10000 &&
		(int)pvp_dot_balance["tick_damage"]==
			(int)pvp_dot_balance["source_tick"]*15*
			(int)pvp_dot_balance["rhythm_percent"]/10000 &&
		fast_dot_profile["active"] && fast_dot_profile["dot"] &&
		(int)fast_dot_profile["dot_tick_damage"]==
			(int)pvp_dot_balance["tick_damage"] &&
		(int)fast_dot_profile["amount"]==
			(int)pvp_dot_balance["total_amount"],
		"目标类型未分层、拓印复制了另一套技能公式或比例被成长属性放大");

	npc->clean_debuff("dot");
	player["/tmp/wanling/assist_at"] = 0;
	npc->set_life(2);
	mapping guarded_dot = PETD->perform_pet_pve_assist(player,npc);
	mapping guarded_tick = npc->process_dot_tick();
	check("灵宠持续伤害保留最后1点生命且不抢人物击杀与掉落归属",
		guarded_dot["ok"] && guarded_dot["type"]=="dot" &&
		guarded_tick["active"] && !guarded_tick["defeated"] &&
		(int)guarded_tick["damage"]==1 && npc->get_cur_life()==1,
		"灵宠后台持续伤害可以直接击杀目标或没有真实结算");
	if(player->query_in_combat())
		player->_clean_fight();
	if(npc->query_in_combat())
		npc->_clean_fight();

	if(dot_boss) destruct(dot_boss);
	mapping forgotten = PETD->forget_pet_imprinted_skill(player,pet_id);
	mapping core_removed = PETD->unequip_pet_gear(player,pet_id,
		"spirit_core");
	gear_state = PETD->query_pet_equipment_state(player,pet_id);
	string core_id = "";
	foreach((array)gear_state["gear_inventory"],mapping gear)
		if((string)gear["slot"]=="spirit_core")
			core_id = (string)gear["id"];
	mapping core_restored = PETD->equip_pet_gear(player,pet_id,core_id);
	PETD->test_grant_pet_species(player,"dangkang");
	mapping second_state = PETD->query_pet_state(player);
	mapping second_pet = find_pet_species(second_state,"dangkang");
	mapping shared_reject = PETD->equip_pet_gear(player,
		(string)second_pet["id"],core_id);
	check("遗忘后可卸装重穿且同一件宠物装备不能被两宠共享",
		forgotten["ok"] && core_removed["ok"] && core_restored["ok"] &&
		!shared_reject["ok"],
		"技能残留锁死灵核、重穿失败或装备引用可被复制");

	PETD->test_add_pet_material(player,"spirit_mark",5);
	mapping before_forge = PETD->query_pet_state(player);
	mapping forged = PETD->forge_pet_gear(player,"beast_armor");
	mapping after_forge = PETD->query_pet_equipment_state(player,pet_id);
	string forged_id = forged["ok"] ? (string)forged["gear"]["id"] : "";
	int quality = forged["ok"] ? (int)forged["gear"]["quality"] : 0;
	mapping dismantled = PETD->dismantle_pet_gear(player,forged_id);
	mapping after_dismantle = PETD->query_pet_state(player);
	check("灵印凝炼与闲置装备分解形成守恒闭环并通过原子存档",
		forged["ok"] && sizeof((array)after_forge["gear_inventory"])==4 &&
		(int)before_forge["materials"]["spirit_mark"]==5 &&
		dismantled["ok"] &&
		(int)after_dismantle["materials"]["spirit_mark"]==quality*2 &&
		sizeof((array)after_dismantle["gear_inventory"])==3,
		"凝炼未扣材料、分解未返还或装备栏数量不守恒");

	PETD->drop_test_pet_cache(player->query_account_owner());
	mapping restored = PETD->query_pet_state(player);
	check("V4装备、派生属性与空拓印状态重载后完整一致",
		restored["ok"] && (int)restored["version"]==4 &&
		sizeof((array)restored["gear_inventory"])==3 &&
		sizeof((mapping)find_pet_species(restored,"wenyaoyu")["equipment"])==3 &&
		!find_pet_species(restored,"wenyaoyu")["imprinted_skill"],
		"宠物装备或技能状态仅保存在内存");
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
	player->move(test_room);
	mapping child_activated = PETD->set_active_pet(player,
		(string)child["id"]);
	mapping child_presence = PETD->query_pet_battle_presence(player);
	object fusion_target = make_npc(player,50);
	player->set_life(player->query_life_max()/2);
	player->set_mofa(player->query_mofa_max()/2);
	player["/tmp/wanling/assist_at"] = 0;
	player->_fight(fusion_target);
	fusion_target->_fight(player);
	player->heart_beat();
	mapping fusion_presence = PETD->query_pet_battle_presence(player);
	mapping fusion_event = mappingp(fusion_presence["recent_event"]) ?
		fusion_presence["recent_event"] : ([]);
	int all_runes_visible = sizeof((array)child["skills"])==3;
	foreach((array)child["skills"],string rune)
		all_runes_visible = all_runes_visible &&
			search((string)(fusion_event["skill"] || ""),rune)!=-1;
	check("阴阳融合宠三枚父系灵纹同步到战斗并作为一个共鸣组合真实触发",
		child_activated["ok"] && (int)fusion_event["amount"]>0 &&
		child_presence["rune_combo"] && fusion_event["rune_combo"] &&
		fusion_event["rune_combo_triggered"] &&
		fusion_event["rune_set_triggered"] &&
		Standards.JSON.encode(child_presence["runes"])==
			Standards.JSON.encode(child["skills"]) &&
		Standards.JSON.encode(fusion_event["runes"])==
			Standards.JSON.encode(child["skills"]) && all_runes_visible,
		"融合灵纹只写入档案，出战快照仍回退原种族技能或战斗不触发");
	if(player->query_in_combat())
		player->_clean_fight();
	if(fusion_target->query_in_combat())
		fusion_target->_clean_fight();
	player["/tmp/wanling/pet_skills"] = ({"损坏残片",0,0});
	mapping repaired_presence = PETD->query_pet_battle_presence(player);
	check("损坏的临时灵纹快照安全回退完整原生组合且不拼接残片",
		sizeof((array)repaired_presence["runes"])==3 &&
		search((array)repaired_presence["runes"],"损坏残片")==-1,
		"部分损坏快照与图鉴回退拼接，形成四枚以上伪灵纹");
	PETD->set_active_pet(player,"none");
	PETD->set_active_pet(player,(string)child["id"]);
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
	if(fusion_target) destruct(fusion_target);
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
	mapping immediate_restart = PETD->start_rift(players[0]);
	mapping immediate_lost = immediate_restart["ok"] ?
		run_rift(players,0) : ([]);
	check("裂隙拒绝两人凑数且三名不同账号玩家可在12轮内协作完成",
		!too_few["ok"] && started["ok"] && won["ok"] &&
		won["status"]=="won" && (int)won["round"]<=12,
		"人数门槛、回合上限或正确机制结算失败");
	check("胜利资格落盘后无需等待全员手动领取即可立即重开",
		immediate_restart["ok"] && immediate_lost["ok"] &&
		immediate_lost["status"]=="lost",
		"上一场已持久化奖励仍占用运行时会话，导致队伍无法继续挑战");

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
	// 玩家真实反馈路径：失败后解散旧队、重新组队会产生新的 term_id。
	// 旧 lost 会话不能继续抢占角色的裂隙路由。
	TERMD->destory_term(test_team_id,players[0]->query_name());
	foreach(players,object player)
		player->set_term("noterm");
	test_team_id = TERMD->term_create(players[0]->query_name());
	TERMD->add_termer(test_team_id,players[1]->query_name(),
		players[1]->query_name_cn());
	TERMD->add_termer(test_team_id,players[2]->query_name(),
		players[2]->query_name_cn());
	mapping restart = PETD->start_rift(players[0]);
	mapping restart_action = PETD->take_rift_action(players[0],"break");
	check("缚灵不能靠普通输出绕过且失败后重组新队可立即重开行动",
		bad_start["ok"] && lost["status"]=="lost" &&
		(int)lost["round"]<=12 && restart["ok"] &&
		restart["session"]["status"]=="active" &&
		restart_action["ok"],
		"错误行动仍赢得裂隙、旧失败会话抢路由或重组后无法行动");
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

void test_rift_same_account_participants(object independent)
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
	mapping starter = PETD->choose_starter_pet(root_player,"dangkang");
	root_player->set_life(root_player->query_life_max());
	if(child)
		child->set_life(child->query_life_max());
	independent->set_life(independent->query_life_max());
	root_player->move(test_room);
	if(child) child->move(test_room);
	independent->move(test_room);
	root_player->set_term("noterm");
	if(child) child->set_term("noterm");
	independent->set_term("noterm");
	string team_id = TERMD->term_create(root_player->query_name());
	int child_add = 0;
	if(child)
		child_add = TERMD->add_termer(team_id,child->query_name(),
			child->query_name_cn());
	int independent_add = TERMD->add_termer(team_id,independent->query_name(),
		independent->query_name_cn());
	mapping team_snapshot = TERMD->query_term_m(team_id);
	mapping before = PETD->query_pet_state(root_player);
	int root_exp_before = root_player->query_exp();
	int child_exp_before = child ? child->query_exp() : 0;
	int root_money_before = root_player->query_account();
	int child_money_before = child ? child->query_account() : 0;
	mapping started = PETD->start_rift(root_player);
	mapping won = started["ok"] ?
		run_rift(({root_player,child,independent}),1) : ([]);
	int root_exp_after_win = root_player->query_exp();
	int child_exp_after_win = child ? child->query_exp() : 0;
	int root_money_after_win = root_player->query_account();
	int child_money_after_win = child ? child->query_account() : 0;
	mapping pending = PETD->query_pet_state(root_player);
	mapping root_claim = PETD->claim_rift_reward(root_player,9999,9999);
	mapping child_claim = PETD->claim_rift_reward(child,9999,9999);
	mapping independent_claim = PETD->claim_rift_reward(
		independent,9999,9999);
	mapping after = PETD->query_pet_state(root_player);
	mapping cleared = PETD->query_rift_state(child);
	check("同一注册账号的不同角色可补足3人行动位",
		created["ok"] && child && starter["ok"] &&
		started["ok"] && won["ok"] &&
		won["status"]=="won",
		"同账号角色仍被错误拒绝或无法独立行动: starter="+
		(string)starter["message"]+" start="+(string)started["message"]+
		" won="+(string)won["message"]+" add="+(string)child_add+"/"+
		(string)independent_add+" team="+(string)sizeof(team_snapshot)+
		" term="+(child ? child->query_term() : "missing")+"/"+
		independent->query_term()+" level="+
		(string)(child ? child->query_level() : 0)+"/"+
		(string)independent->query_level()+" life="+
		(string)(child ? child->get_cur_life() : 0)+"/"+
		(string)independent->get_cur_life()+" env="+
		(string)(child && environment(child)==environment(root_player))+"/"+
		(string)(environment(independent)==environment(root_player)));
	check("同账号多角色每场只产生一份共享万灵奖励",
		sizeof((mapping)pending["pending_rift_rewards"])==1 &&
		root_claim["ok"] && !child_claim["ok"] &&
		independent_claim["ok"] &&
		(int)after["materials"]["spirit_mark"]==
			(int)before["materials"]["spirit_mark"]+5 &&
		(int)after["weekly"]["rift_wins"]==
			(int)before["weekly"]["rift_wins"]+1 && !cleared["ok"],
		"共享档案重复发奖、周次数翻倍或已结算会话未清理: root="+
		(string)root_claim["message"]+" child="+
		(string)child_claim["message"]+" independent="+
		(string)independent_claim["message"]);
	check("同账号每个真实参战角色都独立获得幂等经验金币奖励",
		root_exp_after_win>root_exp_before &&
		child_exp_after_win>child_exp_before &&
		root_money_after_win>root_money_before &&
		child_money_after_win>child_money_before &&
		mappingp(root_player["/wanling/rift_character_rewards"]) &&
		mappingp(child["/wanling/rift_character_rewards"]) &&
		sizeof((mapping)root_player["/wanling/rift_character_rewards"])==1 &&
		sizeof((mapping)child["/wanling/rift_character_rewards"])==1 &&
		root_player->query_exp()==root_exp_after_win &&
		child->query_exp()==child_exp_after_win &&
		root_player->query_account()==root_money_after_win &&
		child->query_account()==child_money_after_win,
		"同账号第二角色零奖励，或点击共享领奖时重复发放角色奖励");
	int repeated_sessions_ok = 1;
	for(int cycle=2;cycle<=3;cycle++){
		int one_root_exp = root_player->query_exp();
		int one_child_exp = child ? child->query_exp() : 0;
		int one_root_money = root_player->query_account();
		int one_child_money = child ? child->query_account() : 0;
		mapping one_started = PETD->start_rift(root_player);
		mapping one_won = one_started["ok"] ?
			run_rift(({root_player,child,independent}),1) : ([]);
		mapping one_root_claim = PETD->claim_rift_reward(
			root_player,9999,9999);
		mapping one_independent_claim = PETD->claim_rift_reward(
			independent,9999,9999);
		repeated_sessions_ok = repeated_sessions_ok &&
			one_started["ok"] && one_won["status"]=="won" &&
			one_root_claim["ok"] && one_independent_claim["ok"] &&
			root_player->query_exp()>one_root_exp &&
			child->query_exp()>one_child_exp &&
			root_player->query_account()>one_root_money &&
			child->query_account()>one_child_money;
	}
	mapping after_three = PETD->query_pet_state(root_player);
	check("同账号多角色连续完成3场也不会间歇性漏发或重复发放",
		repeated_sessions_ok &&
		sizeof((mapping)root_player["/wanling/rift_character_rewards"])==3 &&
		sizeof((mapping)child["/wanling/rift_character_rewards"])==3 &&
		(int)after_three["materials"]["spirit_mark"]==
			(int)before["materials"]["spirit_mark"]+15 &&
		(int)after_three["weekly"]["rift_wins"]==
			(int)before["weekly"]["rift_wins"]+3,
		"连续场次角色凭据、共享材料或账号周胜场结算不一致");
	string legacy_session_id =
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
	mapping legacy_record = Standards.JSON.decode(
		Stdio.read_file(pet_file(account_id)));
	legacy_record["pending_rift_rewards"][legacy_session_id] = ([
		"boss_species":"kui",
		"won_at":time(),
		"expires_at":time()+3600,
	]);
	Stdio.write_file(pet_file(account_id),
		Standards.JSON.encode(legacy_record));
	PETD->drop_test_pet_cache(account_id);
	int legacy_exp_before = root_player->query_exp();
	int legacy_money_before = root_player->query_account();
	mapping legacy_claim = PETD->claim_rift_reward(
		root_player,9999,9999);
	mapping legacy_after = PETD->query_pet_state(root_player);
	check("更新前无角色列表的待领奖励可迁移且只补发当前角色一次",
		legacy_claim["ok"] && root_player->query_exp()>legacy_exp_before &&
		root_player->query_account()>legacy_money_before &&
		(int)legacy_after["materials"]["spirit_mark"]==
			(int)after_three["materials"]["spirit_mark"]+5 &&
		!legacy_after["pending_rift_rewards"][legacy_session_id] &&
		sizeof((mapping)root_player["/wanling/rift_character_rewards"])==4,
		"旧版本待领奖励仍漏发角色收益、重复发放或无法完成清理");
	string rift_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_pet_mod/rift.pike");
	check("裂隙共享奖励按精确注册账号标识归并",
		search(rift_source,
			"participant_account_ids[member_id] = member_account")!=-1 &&
		search(rift_source,"lower_case(member_account)")==-1,
		"大小写不同的合法注册账号可能被误当成同一账号");
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

void test_hidden_luan_owner_revive()
{
	werror("\n【万灵测试】隐藏鸾鸟与回生羽复活主人\n");
	string account_id = "xd99testunitpetluan";
	object player = create_test_player(account_id,"human","jianxian");
	player->level = 70;
	player->set_att_by_level();
	player->save_with_result();
	mapping chosen = PETD->choose_starter_pet(player,"dangkang");
	mapping before = PETD->query_pet_state(player);
	object normal = make_npc(player,70);
	mapping normal_drop = PETD->test_record_hidden_luan_drop(player,
		normal,0);
	player->level = 76;
	player->set_att_by_level();
	object gap_boss = make_npc(player,70);
	gap_boss->_boss = 1;
	mapping gap_counted = PETD->test_record_hidden_luan_drop(player,
		gap_boss,9999);
	player->level = 70;
	player->set_att_by_level();
	object first_boss = make_npc(player,70);
	first_boss->_boss = 1;
	player["/pet_battle/source"] = "personal";
	mapping missed = PETD->test_record_hidden_luan_drop(player,
		first_boss,9999);
	mapping duplicate = PETD->test_record_hidden_luan_drop(player,
		first_boss,0);
	player["/pet_battle/source"] = "shared";
	check("鸾鸟累计70级以上真实首领且不限玩家等级差",
		chosen["ok"] && (int)before["catalog_total"]==15 &&
		!normal_drop["eligible"] && gap_counted["ok"] &&
		gap_counted["eligible"] && !gap_counted["dropped"] &&
		(string)gap_counted["audit_reason"]=="roll_miss" &&
		(int)gap_counted["pity"]==1 &&
		missed["ok"] &&
		missed["eligible"] && !missed["dropped"] &&
		(string)missed["audit_reason"]=="roll_miss" &&
		(int)missed["pity"]==2 && duplicate["ok"] &&
		(string)duplicate["audit_reason"]=="duplicate_npc" &&
		(int)duplicate["pity"]==2,
		"高等级玩家未计入70级首领、概率落空或同一首领去重不可核验");

	int pity_set = PETD->test_set_hidden_luan_pity(player,499);
	object pity_boss = make_npc(player,70);
	pity_boss->_boss = 1;
	mapping guaranteed = PETD->test_record_hidden_luan_drop(player,
		pity_boss,9999);
	mapping collected = PETD->query_pet_state(player);
	mapping luan = find_pet_species(collected,"luanniao");
	check("第500次合格首领无视随机值保底完整鸾鸟并重置账号计数",
		pity_set && guaranteed["ok"] && guaranteed["dropped"] &&
		(string)guaranteed["audit_reason"]=="pity_guarantee" &&
		sizeof(luan) && (string)luan["source"]=="hidden_world_boss_pity" &&
		(int)collected["hidden_luan_pity"]==0 &&
		(int)collected["catalog_total"]==16,
		"隐藏掉率无保底、生成残片而非完整宠物或收录后图鉴未解锁");
	string collection_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_pet_mod/collection.pike") || "";
	check("鸾鸟首领拒绝、计数、概率、保底、失败与成功均写审计日志",
		search(collection_source,"pet_hidden_drop_audit.log")!=-1 &&
		search(collection_source,"npc_level_below_70")!=-1 &&
		search(collection_source,"pity_guarantee")!=-1 &&
		search(collection_source,"save_failed")!=-1,
		"当前仍只能在掉落成功后看到日志，无法解释1300次未出的原因");

	mapping attack_grant = PETD->test_grant_pet_species(player,"bifang");
	mapping with_attack = PETD->query_pet_state(player);
	mapping attack_pet = find_pet_species(with_attack,"bifang");
	mapping activated = PETD->set_active_pet(player,(string)luan["id"]);
	mapping fusion = PETD->query_pet_fusion_preview(player,
		(string)luan["id"],(string)attack_pet["id"]);
	check("隐藏鸾鸟可正常设为协战但不能被阴阳合成永久销毁",
		attack_grant["ok"] && activated["ok"] && !fusion["ok"] &&
		search((string)fusion["message"],"不能作为合成材料")!=-1,
		"隐藏宠物无法出战或可被融合导致复活能力丢失/继承");

	player->skills["xuehailieshang"] = ({1,0});
	PETD->test_add_pet_material(player,"spirit_dew",100);
	int luan_trained = 1;
	for(int level=1;level<20;level++)
		luan_trained = luan_trained &&
			PETD->train_pet_level(player,(string)luan["id"])["ok"];
	PETD->test_add_pet_material(player,"skill_rune",1);
	mapping luan_imprinted = PETD->imprint_pet_skill(player,
		(string)luan["id"],"xuehailieshang");
	player->move(test_room);
	player->set_life(player->query_life_max()/2);
	object basic_target = make_npc(player,70);
	int basic_life_before = player->get_cur_life();
	int basic_target_before = basic_target->get_cur_life();
	mapping basic_heal = PETD->perform_pet_basic_assist(player,basic_target);
	check("鸾鸟拓印攻击灵技后仍保留物种被动治疗",
		luan_trained && luan_imprinted["ok"] && basic_heal["ok"] &&
		basic_heal["type"]=="heal" && (int)basic_heal["amount"]>0 &&
		basic_heal["skill_name"]=="灵羽回春" &&
		player->get_cur_life()>basic_life_before &&
		basic_target->get_cur_life()==basic_target_before,
		"拓印主动效果覆盖了鸾鸟基础疗愈或错误伤害目标");
	// 不直接调用PETD，而是走人物真实战斗心跳；同时让拓印主灵技保持
	// 冷却，证明本次回血来自鸾鸟固有疗愈而不是拓印效果。
	player->set_life(player->query_life_max()/2);
	player["/tmp/wanling/assist_at"] = time();
	int heartbeat_life_before = player->get_cur_life();
	player->_fight(basic_target);
	basic_target->_fight(player);
	player->heart_beat();
	check("鸾鸟学习攻击灵技后经真实战斗心跳继续被动回血",
		player->get_cur_life()>heartbeat_life_before &&
		(int)player["/tmp/wanling/assist_at"]>0,
		"直接调用可回血，但真实heart_beat没有执行固有疗愈");
	if(player->query_in_combat())
		player->_clean_fight();
	if(basic_target->query_in_combat())
		basic_target->_clean_fight();
	// 模拟跨Worker使账号缓存失效后重建临时态；拓印和物种均从唯一
	// 宠物档案恢复，再次通过真实心跳确认固有疗愈没有丢失。
	PETD->drop_test_pet_cache(player->query_account_owner());
	PETD->mark_pet_player_runtime_stale(player);
	player->set_life(player->query_life_max()/2);
	player["/tmp/wanling/assist_at"] = time();
	int worker_life_before = player->get_cur_life();
	player->_fight(basic_target);
	basic_target->_fight(player);
	player->heart_beat();
	mapping worker_presence = PETD->query_pet_battle_presence(player);
	check("鸾鸟拓印状态跨Worker重建后仍保留固有疗愈",
		!(int)player["/tmp/wanling/runtime_stale"] &&
		worker_presence["species"]=="luanniao" &&
		worker_presence["basic_skill"]=="灵羽回春" &&
		search((string)worker_presence["native_passive"],"不会覆盖")!=-1 &&
		player->get_cur_life()>worker_life_before,
		"缓存换代后鸾鸟种族、拓印战斗态或固有疗愈丢失");
	if(player->query_in_combat())
		player->_clean_fight();
	if(basic_target->query_in_combat())
		basic_target->_clean_fight();
	player->set_life(player->query_life_max());
	if(basic_target)
		destruct(basic_target);

	player->move(test_room);
	object duel_killer = create_test_player(
		"xd99testunitpetluankiller","monst","yinggui");
	duel_killer->level = 70;
	duel_killer->set_att_by_level();
	duel_killer->move(test_room);
	player->set_life(0);
	player->set_mofa(0);
	player->kill_flag = 0;
	duel_killer->kill_flag = 0;
	int duel_reject = PETD->try_pet_owner_revive(player,duel_killer);
	object away_room = clone(ROOT+"/gamelib/d/wanling/wanlingtai");
	duel_killer->move(away_room);
	player->kill_flag = 1;
	duel_killer->kill_flag = 1;
	int cross_room_reject = PETD->try_pet_owner_revive(player,duel_killer);
	duel_killer->move(test_room);
	player->sucide = 1;
	int suicide_reject = PETD->try_pet_owner_revive(player,duel_killer);
	mapping before_real_death = PETD->query_pet_state(player);
	check("切磋、跨房间与自杀均不会误触发或消耗回生羽",
		!duel_reject && !cross_room_reject && !suicide_reject &&
		!(int)before_real_death["daily"]["owner_revive"],
		"非真实死亡路径消耗了账号每日保命次数");

	player->sucide = 0;
	player->kill_flag = 1;
	object killer = make_npc(player,70);
	player->set_life(0);
	player->set_mofa(0);
	int expected_life = player->query_life_max()*15/100;
	int expected_mofa = player->query_mofa_max()*10/100;
	if(expected_life<1) expected_life = 1;
	if(expected_mofa<1) expected_mofa = 1;
	int revived = PETD->try_pet_owner_revive(player,killer);
	mapping after_revive = PETD->query_pet_state(player);
	mapping presence = PETD->query_pet_battle_presence(player);
	check("回生羽在真实死亡结算前复活主人并恢复15%生命与10%法力",
		revived && player->get_cur_life()==expected_life &&
		player->get_cur_mofa()==expected_mofa &&
		(int)after_revive["daily"]["owner_revive"]==1 &&
		mappingp(presence["owner_revive"]) &&
		(int)presence["owner_revive"]["remaining"]==0 &&
		mappingp(presence["recent_event"]) &&
		presence["recent_event"]["type"]=="revive" &&
		presence["recent_event"]["skill"]=="回生羽",
		"恢复比例、永久次数、战斗小窗事件或技能名称错误");

	player->set_life(0);
	player->set_mofa(0);
	int repeated = PETD->try_pet_owner_revive(player,killer);
	PETD->drop_test_pet_cache(account_id);
	mapping reloaded = PETD->query_pet_state(player);
	check("同账号每日只能复活一次且重载宠物档案后仍不能重复触发",
		!repeated && player->get_cur_life()==0 &&
		(int)reloaded["daily"]["owner_revive"]==1,
		"同日重复死亡或清缓存可复制回生羽次数");
	player->set_life(player->query_life_max());
	player->set_mofa(player->query_mofa_max());

	object healer = create_test_player(
		"xd99testunitpetluanhealer","third","lingyi");
	healer->level = 120;
	healer->set_att_by_level();
	healer->move(test_room);
	PETD->choose_starter_pet(healer,"lushu");
	PETD->test_grant_pet_species(healer,"luanniao");
	mapping healer_state = PETD->query_pet_state(healer);
	mapping healer_luan = find_pet_species(healer_state,"luanniao");
	PETD->set_active_pet(healer,(string)healer_luan["id"]);
	foreach(({"lingzhen","huichun","muxi","qingxin","huxin"}),
	   string mastery_skill)
		healer->skills[mastery_skill] = ({5,0});
	healer->kill_flag = 1;
	duel_killer->kill_flag = 1;
	healer->_fight(duel_killer);
	duel_killer->_fight(healer);
	healer->set_life(0);
	healer->fight_die();
	mapping healer_after = PETD->query_pet_state(healer);
	check("灵医百炼复苏真实触发时优先保命且不消耗鸾鸟每日次数",
		healer->get_cur_life()==healer->query_life_max()*25/100 &&
		healer->query_lingyi_auto_revive_used()==1 &&
		!(int)healer_after["daily"]["owner_revive"],
		"死亡链顺序只存在于源码文字或双重消耗两种复活次数");
	if(away_room) destruct(away_room);
	if(normal) destruct(normal);
	if(first_boss) destruct(first_boss);
	if(pity_boss) destruct(pity_boss);
	if(killer) destruct(killer);
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
	string vue_app_source = Stdio.read_file(ROOT+"/vue_source/js/app.js");
	string vue_css_source = Stdio.read_file(ROOT+"/vue_source/css/app.css");
	string equipment_api_source = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/equipment_panel.pike");
	check("通用灵宠不克隆NPC、不登记SUMMOND且旧家园守宅犬数据零迁移",
		pet_source && search(pet_modules,"clone(")==-1 &&
		search(pet_modules,"register_summon")==-1 &&
		dog_source && home_source && search(dog_source,"PETD")==-1 &&
		search(home_source,"PETD")==-1,
		"万灵系统与方士召唤槽或旧家园犬产生数据耦合");
	int lingyi_revive_pos = search(user_source,
		"try_lingyi_auto_revive(enemy)");
	int pet_revive_pos = search(user_source,
		"PETD->try_pet_owner_revive(me,enemy)");
	int summon_cleanup_pos = search(user_source,
		"SUMMOND->player_death(me->query_name())");
	check("主人死亡链固定为灵医复苏、鸾鸟回生、召唤清理与死亡惩罚",
		lingyi_revive_pos!=-1 && pet_revive_pos>lingyi_revive_pos &&
		summon_cleanup_pos>pet_revive_pos,
		"隐藏宠物抢占灵医特色或复活发生在死亡惩罚之后");
	check("旧文字入口、Vue快捷入口与Header随行宠物均接入万灵谱",
		user_source && search(user_source,"[共享宠物:pet]")!=-1 &&
		vue_source && search(vue_source,"sendQuickCommand('pet')")!=-1 &&
		search(vue_source,"header-pet-companion")!=-1 &&
		vue_app_source && search(vue_app_source,"headerPet()")!=-1 &&
		search(vue_app_source,"playerStats?.pet_assist")!=-1 &&
		vue_css_source && search(vue_css_source,
			".header-pet-companion")!=-1,
		"客户端没有万灵入口或Header未显示当前随行宠物");
	check("万灵成长助手与灵宠跨级感知已接入命令、状态和响应式前端",
		pet_source && search(pet_modules,"query_pet_growth_guidance")!=-1 &&
		search(Stdio.read_file(ROOT+"/gamelib/cmds/pet.pike") || "",
			"render_growth_guide")!=-1 &&
		search(vue_source,"pet-level-up-stage")!=-1 &&
		search(vue_app_source,"handlePetLevelChange(previousPet")!=-1 &&
		search(vue_css_source,"@keyframes petLevelUpEnter")!=-1,
		"成长建议、直达入口、升级状态差分或视觉层没有完整接通");
	string pet_command_source = Stdio.read_file(ROOT+
		"/gamelib/cmds/pet.pike") || "";
	string daily_source = Stdio.read_file(ROOT+
		"/gamelib/cmds/daily_cultivation.pike") || "";
	check("万灵主页、宠物详情和本周目标均直显灵纹符数量与获取入口",
		search(pet_command_source,
			"灵纹符获取：每周平复3次万灵裂隙后")!=-1 &&
		search(pet_command_source,"[获取说明:pet materials]")!=-1 &&
		search(pet_command_source,"[查看灵纹符获取:daily_cultivation]")!=-1 &&
		search(daily_source,"[灵纹符×2:wanling_rift weekly rune]")!=-1 &&
		search(daily_source,"不进入人物背包")!=-1,
		"数量、来源、周进度或切换失败后的直达入口仍有缺失");
	check("头像装备面板使用只读结构接口并复用服务器换装命令校验",
		equipment_api_source &&
		search(equipment_api_source,"all_inventory(player)")!=-1 &&
		search(equipment_api_source,"action_cmd")!=-1 &&
		search(equipment_api_source,"player->wear(")==-1 &&
		search(equipment_api_source,"player->wield(")==-1 &&
		search(vue_source,"@click=\"openEquipmentPanel\"")!=-1 &&
		search(vue_source,"equipment-human-silhouette")!=-1 &&
		search(vue_app_source,"/api/equipment_panel")!=-1 &&
		search(vue_css_source,".equipment-panel-overlay")!=-1,
		"头像入口、身体槽位、只读接口或原有命令安全边界未接通");
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
				test_pet_player_level_cap();
			test_legacy_pet_migration();
			 test_same_account_active_pet();
			test_hunt_and_assist(profession_players[0],profession_players[1]);
			test_solo_pve_fragment_channels();
			test_pet_auto_combat_growth();
			test_pet_equipment_and_skill_imprint();
			test_pet_batch_growth_and_fusion();
			test_hidden_luan_owner_revive();
			test_rift(profession_players[0..2]);
			// 上一项特意清理了前三个账号的宠物数据；重新初契供反刷和论道。
			for(int i=0;i<3;i++){
				PETD->drop_test_pet_cache(profession_players[i]->query_name());
				PETD->choose_starter_pet(profession_players[i],
					PETD->query_starter_species()[i]);
			}
			test_rift_same_account_participants(profession_players[2]);
			test_duel(profession_players[0],profession_players[1]);
			test_corruption_and_wiring();
		}
	};
	if(err){
		error_desc = describe_error(err)+"\n"+describe_backtrace(err);
		check("测试脚本自身无未捕获异常",0,error_desc);
	}
	cleanup_all();
	werror("\n山海万灵测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],test_results["passed"],test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
