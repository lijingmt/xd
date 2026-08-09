/** 账号宠物数据的校验、原子保存和周期刷新。 */

#ifndef XIAND_PET_PERSISTENCE_PIKE
#define XIAND_PET_PERSISTENCE_PIKE

private int valid_pet_userid(string value)
{
	if(!value || sizeof(value)<2 || sizeof(value)>64 ||
	   search(value,"..")!=-1)
		return 0;
	for(int i=0;i<sizeof(value);i++){
		int one = value[i];
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9') || one=='_')
			continue;
		return 0;
	}
	return 1;
}

private int valid_pet_id(string value)
{
	if(!value || sizeof(value)!=64)
		return 0;
	for(int i=0;i<sizeof(value);i++){
		int one = value[i];
		if((one>='0' && one<='9') || (one>='a' && one<='f'))
			continue;
		return 0;
	}
	return 1;
}

private string pet_file_path(string account_id)
{
	if(!valid_pet_userid(account_id))
		return "";
	return DATA_ROOT+"accounts/"+
		account_id[sizeof(account_id)-2..]+"/"+
		account_id+".pets.json";
}

private mapping(string:int) empty_pet_materials()
{
	return ([
		"spirit_mark":0,
		"spirit_dew":0,
		"egg_fragment":0,
		"skill_rune":0,
		"cosmetic_dust":0,
		"bond_token":0,
	]);
}

private mapping(string:mixed) empty_pet_record(string account_id)
{
	return ([
		"version":PET_RECORD_VERSION,
		"account_id":account_id,
		"revision":0,
		"created_at":0,
		"updated_at":0,
		"starter_claimed":0,
		"pets":({}),
		"gear_inventory":({}),
		"materials":empty_pet_materials(),
		"active":([]),
		"duel_teams":([]),
		"daily_key":"",
		"daily":(["hunt":0,"rift":0,"pve_fragments":0,
			"owner_revive":0,"opponents":({})]),
		"weekly_key":"",
		"weekly":(["rift_wins":0,"choice_claimed":0]),
		"season_key":"",
		"season":(["wins":0,"losses":0,"draws":0]),
		"rift_pity":0,
		"fusion_pity":0,
		"hidden_luan_pity":0,
		"pending_rift_rewards":([]),
		"rewarded_sessions":([]),
		"persisted":0,
	]);
}

private string two_digit(int value)
{
	if(value<10)
		return "0"+value;
	return ""+value;
}

private string current_pet_day_key(void|int at_time)
{
	mapping now = localtime(at_time || time());
	return (now["year"]+1900)+"-"+two_digit(now["mon"]+1)+"-"+
		two_digit(now["mday"]);
}

private string current_pet_week_key(void|int at_time)
{
	return "week-"+((at_time || time())/604800);
}

private string current_pet_season_key(void|int at_time)
{
	mapping now = localtime(at_time || time());
	return (now["year"]+1900)+"-"+two_digit(now["mon"]+1);
}

private int valid_pet_fusion(mapping fusion)
{
	mapping attributes;
	array parents;
	array traits;
	if(!mappingp(fusion))
		return 0;
	attributes = fusion["attribute_percent"];
	parents = fusion["parents"];
	traits = fusion["traits"];
	if(!stringp(fusion["name"]) || sizeof((string)fusion["name"])<1 ||
	   sizeof((string)fusion["name"])>40 ||
	   search(({"yin","yang"}),(string)fusion["polarity"])==-1 ||
	   (int)fusion["quality"]<1 || (int)fusion["quality"]>4 ||
	   !stringp(fusion["quality_name"]) ||
	   sizeof((string)fusion["quality_name"])>20 ||
	   (int)fusion["generation"]<1 ||
	   (int)fusion["generation"]>3 ||
	   (int)fusion["growth_bonus"]<3 ||
	   (int)fusion["growth_bonus"]>12 ||
	   !mappingp(attributes) || !arrayp(parents) ||
	   sizeof(parents)!=2 || !arrayp(traits) || sizeof(traits)!=2 ||
	   (int)fusion["created_at"]<=0)
		return 0;
	foreach(({"life","attack","defense","spirit","speed"}),
	   string attribute)
		if(!intp(attributes[attribute]) ||
		   (int)attributes[attribute]<102 ||
		   (int)attributes[attribute]>118)
			return 0;
	foreach(parents,mixed species)
		if(!stringp(species) || !shanhai_catalog[(string)species])
			return 0;
	if((string)parents[0]==(string)parents[1])
		return 0;
	foreach(traits,mixed trait)
		if(!stringp(trait) || sizeof((string)trait)<1 ||
		   sizeof((string)trait)>40)
			return 0;
	return 1;
}

private int valid_pet_gear(mapping gear,multiset(string) ids)
{
	string gear_id;
	mapping attributes;
	if(!mappingp(gear))
		return 0;
	gear_id = (string)gear["id"];
	attributes = gear["attributes"];
	if(!valid_pet_id(gear_id) || ids[gear_id] ||
	   search(({"beast_armor","spirit_charm","spirit_core"}),
		(string)gear["slot"])==-1 ||
	   !stringp(gear["name"]) || sizeof((string)gear["name"])<1 ||
	   sizeof((string)gear["name"])>40 ||
	   (int)gear["quality"]<1 || (int)gear["quality"]>4 ||
	   !stringp(gear["quality_name"]) ||
	   sizeof((string)gear["quality_name"])>20 ||
	   (int)gear["level_requirement"]<1 ||
	   (int)gear["level_requirement"]>PET_LEVEL_MAX ||
	   !mappingp(attributes) ||
	   (int)gear["xp_bonus_percent"]<0 ||
	   (int)gear["xp_bonus_percent"]>8 ||
	   !stringp(gear["source"]) || sizeof((string)gear["source"])>40 ||
	   (int)gear["acquired_at"]<=0)
		return 0;
	foreach(({"life","attack","defense","spirit","speed"}),
	   string attribute)
		if(!intp(attributes[attribute]) ||
		   (int)attributes[attribute]<0 ||
		   (int)attributes[attribute]>8)
			return 0;
	ids[gear_id] = 1;
	return 1;
}

private int valid_pet_imprinted_skill(mixed raw_skill)
{
	mapping skill;
	string name;
	if(!raw_skill)
		return 1;
	if(!mappingp(raw_skill))
		return 0;
	skill = raw_skill;
	name = (string)skill["name"];
	if(!name || sizeof(name)<1 || sizeof(name)>64 ||
	   search(name,"/")!=-1 || search(name,"..")!=-1 ||
	   !stringp(skill["name_cn"]) ||
	   sizeof((string)skill["name_cn"])<1 ||
	   sizeof((string)skill["name_cn"])>80 ||
	   search(({"damage","heal"}),(string)skill["effect"])==-1 ||
	   (int)skill["level"]<1 || (int)skill["level"]>100 ||
	   !valid_pet_userid((string)skill["source_character"]) ||
	   (int)skill["learned_at"]<=0)
		return 0;
	return 1;
}

private int valid_pet_equipment_bonus(mapping bonus)
{
	if(!mappingp(bonus) || sizeof(bonus)!=5)
		return 0;
	foreach(({"life","attack","defense","spirit","speed"}),
	   string attribute)
		if(!intp(bonus[attribute]) || (int)bonus[attribute]<0 ||
		   (int)bonus[attribute]>24)
			return 0;
	return 1;
}

private int valid_pet_instance(mapping one,multiset(string) ids,
	multiset(string) species_seen)
{
	string pet_id;
	string species;
	array skills;
	array variants;
	if(!mappingp(one))
		return 0;
	pet_id = (string)one["id"];
	species = (string)one["species"];
	skills = one["skills"];
	variants = one["variants"];
	if(!valid_pet_id(pet_id) || ids[pet_id] ||
	   !shanhai_catalog[species] || species_seen[species] ||
	   (int)one["level"]<1 || (int)one["level"]>PET_LEVEL_MAX ||
	   (int)one["star"]<1 || (int)one["star"]>PET_STAR_MAX ||
	   (int)one["xp"]<0 || (int)one["xp"]>1000000000 ||
	   (int)one["bond"]<1 ||
	   (int)one["bond"]>PET_BOND_MAX || (int)one["bond_xp"]<0 ||
	   (int)one["skill_set"]<0 || (int)one["skill_set"]>2 ||
	   !arrayp(skills) || sizeof(skills)!=3 ||
	   !arrayp(variants) || sizeof(variants)<1 || sizeof(variants)>12 ||
	   !mappingp(one["equipment"]) ||
	   sizeof((mapping)one["equipment"])>3 ||
	   !valid_pet_equipment_bonus(one["equipment_bonus"]) ||
	   !valid_pet_imprinted_skill(one["imprinted_skill"]) ||
	   !stringp(one["source"]) || sizeof((string)one["source"])>40 ||
	   (int)one["acquired_at"]<=0)
		return 0;
	foreach(skills,mixed skill){
		if(!stringp(skill) || sizeof((string)skill)<1 ||
		   sizeof((string)skill)>40)
			return 0;
	}
	foreach(variants,mixed variant_name){
		if(!stringp(variant_name) || sizeof((string)variant_name)>40)
			return 0;
	}
	if(has_index(one,"fusion") && one["fusion"] &&
	   (!mappingp(one["fusion"]) ||
	    !valid_pet_fusion((mapping)one["fusion"])))
		return 0;
	ids[pet_id] = 1;
	species_seen[species] = 1;
	return 1;
}

/**
 * V1没有星级字段，V1/V2没有宠物装备与灵技拓印字段，V1—V3
 * 没有隐藏鸾鸟保底与主人复活字段。迁移只发生在内存，单纯查看
 * 旧档案不会写盘；下一次真实培养会通过原子保存自然升级为V4。
 * 迁移前先限制V1原有等级上限，防止伪造旧数据借新版通过。
 */
private mapping(string:mixed)|zero upgrade_pet_record_unlocked(
	mapping record,string account_id)
{
	mapping upgraded;
	if((int)record["version"]==PET_RECORD_VERSION)
		return record;
	int old_version = (int)record["version"];
	if(search(({1,2,3}),old_version)==-1 ||
	   record["account_id"]!=account_id ||
	   !arrayp(record["pets"]))
		return 0;
	upgraded = copy_value(record);
	foreach((array)upgraded["pets"],mixed one){
		if(!mappingp(one) || (int)one["level"]<1 ||
		   (old_version==1 && (int)one["level"]>30))
			return 0;
		if(old_version==1)
			one["star"] = 1;
		if(old_version<=2){
			one["equipment"] = ([]);
			one["equipment_bonus"] = (["life":0,"attack":0,
				"defense":0,"spirit":0,"speed":0]);
			one["imprinted_skill"] = 0;
		}
	}
	if(old_version<=2)
		upgraded["gear_inventory"] = ({});
	if(!mappingp(upgraded["daily"]))
		return 0;
	upgraded["daily"]["owner_revive"] = 0;
	upgraded["hidden_luan_pity"] = 0;
	upgraded["version"] = PET_RECORD_VERSION;
	upgraded["migration_pending"] = 1;
	return upgraded;
}

private int valid_pet_record(mapping record,string account_id)
{
	array pets;
	mapping materials;
	mapping active;
	mapping duel_teams;
	mapping pending_rewards;
	mapping rewarded;
	array gear_inventory;
	multiset(string) ids = (<>);
	multiset(string) species_seen = (<>);
	multiset(string) gear_ids = (<>);
	multiset(string) equipped_gear_ids = (<>);
	if(!mappingp(record) || record["account_id"]!=account_id ||
	   (int)record["version"]!=PET_RECORD_VERSION ||
	   !arrayp(record["pets"]) || !arrayp(record["gear_inventory"]) ||
	   !mappingp(record["materials"]) ||
	   !mappingp(record["active"]) || !mappingp(record["duel_teams"]) ||
	   !mappingp(record["daily"]) || !mappingp(record["weekly"]) ||
	   !mappingp(record["season"]) ||
	   !mappingp(record["pending_rift_rewards"]) ||
	   !mappingp(record["rewarded_sessions"]))
		return 0;
	pets = record["pets"];
	materials = record["materials"];
	active = record["active"];
	duel_teams = record["duel_teams"];
	pending_rewards = record["pending_rift_rewards"];
	rewarded = record["rewarded_sessions"];
	gear_inventory = record["gear_inventory"];
	if(sizeof(pets)>sizeof(shanhai_catalog) || sizeof(rewarded)>256 ||
	   sizeof(gear_inventory)>PET_GEAR_INVENTORY_MAX ||
	   sizeof(pending_rewards)>32 || sizeof(active)>10 ||
	   sizeof(duel_teams)>10 || (int)record["revision"]<0 ||
	   ((int)record["starter_claimed"]!=0 &&
	    (int)record["starter_claimed"]!=1))
		return 0;
	foreach(pets,mixed one){
		if(!mappingp(one) ||
		   !valid_pet_instance((mapping)one,ids,species_seen))
			return 0;
	}
	foreach(gear_inventory,mixed raw_gear)
		if(!mappingp(raw_gear) ||
		   ids[(string)raw_gear["id"]] ||
		   !valid_pet_gear((mapping)raw_gear,gear_ids))
			return 0;
	foreach(pets,mixed raw_pet){
		mapping pet = raw_pet;
		mapping calculated = (["life":0,"attack":0,"defense":0,
			"spirit":0,"speed":0]);
		foreach((mapping)pet["equipment"];string slot;mixed raw_gear_id){
			string gear_id = (string)raw_gear_id;
			mapping gear = ([]);
			if(search(({"beast_armor","spirit_charm","spirit_core"}),
			   slot)==-1 || !stringp(raw_gear_id) ||
			   !gear_ids[gear_id] || equipped_gear_ids[gear_id])
				return 0;
			foreach(gear_inventory,mixed candidate)
				if((string)candidate["id"]==gear_id){
					gear = candidate;
					break;
				}
			if(!sizeof(gear) || (string)gear["slot"]!=slot)
				return 0;
			equipped_gear_ids[gear_id] = 1;
			foreach(indices(calculated),string attribute)
				calculated[attribute] = (int)calculated[attribute]+
					(int)gear["attributes"][attribute];
		}
		foreach(indices(calculated),string attribute)
			if((int)calculated[attribute]!=
			   (int)pet["equipment_bonus"][attribute])
				return 0;
		if(pet["imprinted_skill"] &&
		   !(string)(pet["equipment"]["spirit_core"] || ""))
			return 0;
	}
	foreach(indices(empty_pet_materials()),string material){
		if(!intp(materials[material]) || (int)materials[material]<0 ||
		   (int)materials[material]>1000000000)
			return 0;
	}
	foreach(active;string character_id;mixed pet_id){
		if(!valid_pet_userid(character_id) || !stringp(pet_id) ||
		   !ids[(string)pet_id])
			return 0;
		foreach(active;string other_character;mixed other_pet_id){
			if(other_character!=character_id && other_pet_id==pet_id)
				return 0;
		}
	}
	foreach(duel_teams;string character_id;mixed team){
		multiset(string) team_seen = (<>);
		if(!valid_pet_userid(character_id) || !arrayp(team) ||
		   sizeof((array)team)>3)
			return 0;
		foreach((array)team,mixed pet_id){
			if(!stringp(pet_id) || !ids[(string)pet_id] ||
			   team_seen[(string)pet_id])
				return 0;
			team_seen[(string)pet_id] = 1;
		}
	}
	if(!arrayp(record["daily"]["opponents"]) ||
	   sizeof((array)record["daily"]["opponents"])>
		PET_DUEL_DAILY_OPPONENTS ||
	   (int)record["daily"]["hunt"]<0 ||
	   (int)record["daily"]["hunt"]>4 ||
	   (int)record["daily"]["rift"]<0 ||
	   (int)record["daily"]["rift"]>1 ||
	   (int)record["daily"]["pve_fragments"]<0 ||
	   (int)record["daily"]["pve_fragments"]>
		PET_PVE_FRAGMENT_DAILY_CAP ||
	   !intp(record["daily"]["owner_revive"]) ||
	   ((int)record["daily"]["owner_revive"]!=0 &&
	    (int)record["daily"]["owner_revive"]!=1) ||
	   (int)record["weekly"]["rift_wins"]<0 ||
	   (int)record["weekly"]["rift_wins"]>1000 ||
	   ((int)record["weekly"]["choice_claimed"]!=0 &&
	    (int)record["weekly"]["choice_claimed"]!=1) ||
	   (int)record["season"]["wins"]<0 ||
	   (int)record["season"]["losses"]<0 ||
	   (int)record["season"]["draws"]<0 ||
	   (int)record["rift_pity"]<0 || (int)record["rift_pity"]>1000)
		return 0;
	if((int)record["fusion_pity"]<0 ||
	   (int)record["fusion_pity"]>5 ||
	   !intp(record["hidden_luan_pity"]) ||
	   (int)record["hidden_luan_pity"]<0 ||
	   (int)record["hidden_luan_pity"]>=PET_HIDDEN_LUAN_PITY)
		return 0;
	foreach((array)record["daily"]["opponents"],mixed opponent)
		if(!stringp(opponent) || !valid_pet_userid((string)opponent))
			return 0;
	foreach(pending_rewards;string session_id;mixed raw_reward){
		mapping reward;
		if(!valid_pet_id(session_id) || !mappingp(raw_reward))
			return 0;
		reward = raw_reward;
		if(!shanhai_catalog[(string)reward["boss_species"]] ||
		   (int)reward["won_at"]<=0 ||
		   (int)reward["expires_at"]<(int)reward["won_at"])
			return 0;
	}
	foreach(rewarded;string session_id;mixed claimed_at){
		if(!valid_pet_id(session_id) || !intp(claimed_at) ||
		   (int)claimed_at<=0)
			return 0;
	}
	return 1;
}

private void cache_pet_record_unlocked(string account_id,mapping record)
{
	if(!pet_cache[account_id] && sizeof(pet_cache)>=PET_CACHE_MAX){
		array(string) account_ids = indices(pet_cache);
		if(sizeof(account_ids))
			m_delete(pet_cache,account_ids[0]);
	}
	pet_cache[account_id] = copy_value(record);
}

private mapping(string:mixed)|zero decode_pet_file(string path,
	string account_id)
{
	string source;
	mixed decoded = 0;
	mixed err;
	if(Stdio.file_size(path)<=0 ||
	   Stdio.file_size(path)>PET_FILE_MAX_SIZE)
		return 0;
	source = Stdio.read_file(path);
	err = catch{
		decoded = Standards.JSON.decode(source);
	};
	if(err || !mappingp(decoded))
		return 0;
	decoded = upgrade_pet_record_unlocked((mapping)decoded,account_id);
	if(!decoded || !valid_pet_record((mapping)decoded,account_id))
		return 0;
	decoded["persisted"] = 1;
	return decoded;
}

private mapping(string:mixed)|zero load_pet_record_unlocked(
	string account_id)
{
	string path = pet_file_path(account_id);
	mapping(string:mixed)|zero record;
	if(pet_cache[account_id])
		return copy_value(pet_cache[account_id]);
	record = decode_pet_file(path,account_id);
	if(record){
		cache_pet_record_unlocked(account_id,record);
		return copy_value(record);
	}
	// 任何物理代文件存在都说明曾经有数据；损坏时失败关闭，不能重建空档。
	if(Stdio.file_size(path)>0 || Stdio.file_size(path+".bak")>0 ||
	   Stdio.file_size(path+".tmp")>0)
		return 0;
	return empty_pet_record(account_id);
}

private void prune_pet_reward_sessions(mapping record)
{
	mapping rewarded = record["rewarded_sessions"];
	while(sizeof(rewarded)>220){
		string oldest_id = "";
		int oldest_time = time();
		foreach(rewarded;string session_id;mixed claimed_at){
			if((int)claimed_at<=oldest_time){
				oldest_time = (int)claimed_at;
				oldest_id = session_id;
			}
		}
		if(oldest_id=="")
			break;
		m_delete(rewarded,oldest_id);
	}
}

private int save_pet_record_unlocked(mapping(string:mixed) record)
{
	string account_id = (string)record["account_id"];
	string path = pet_file_path(account_id);
	string dir = dirname(path);
	string temp_path = path+".tmp";
	string backup_temp = path+".bak.tmp";
	string encoded;
	mapping disk_record;
	int live_size;
	int ok = 0;
	mixed err;
	if(path=="")
		return 0;
	prune_pet_reward_sessions(record);
	if(!valid_pet_record(record,account_id))
		return 0;
	disk_record = copy_value(record);
	m_delete(disk_record,"persisted");
	m_delete(disk_record,"migration_pending");
	disk_record["version"] = PET_RECORD_VERSION;
	disk_record["updated_at"] = time();
	if((int)disk_record["created_at"]<=0)
		disk_record["created_at"] = time();
	encoded = Standards.JSON.encode(disk_record);
	mkdir(DATA_ROOT+"accounts");
	mkdir(dir);
	err = catch{
		rm(temp_path);
		rm(backup_temp);
		if(Stdio.write_file(temp_path,encoded)>0 &&
		   Stdio.file_size(temp_path)==sizeof(encoded)){
			live_size = Stdio.file_size(path);
			if(live_size>0 && decode_pet_file(path,account_id)){
				Stdio.cp(path,backup_temp);
				if(Stdio.file_size(backup_temp)==live_size &&
				   mv(backup_temp,path+".bak") && mv(temp_path,path))
					ok = Stdio.file_size(path)==sizeof(encoded);
			}
			else if(live_size<=0 && mv(temp_path,path))
				ok = Stdio.file_size(path)==sizeof(encoded);
		}
	};
	if(err)
		werror("[PETD] 账号万灵谱保存异常: %s\n",describe_error(err));
	if(!ok){
		rm(temp_path);
		rm(backup_temp);
		return 0;
	}
	record["persisted"] = 1;
	m_delete(record,"migration_pending");
	record["updated_at"] = disk_record["updated_at"];
	record["created_at"] = disk_record["created_at"];
	cache_pet_record_unlocked(account_id,record);
	return 1;
}

private int refresh_pet_periods_unlocked(mapping record,void|int at_time)
{
	int changed = 0;
	string day_key = current_pet_day_key(at_time);
	string week_key = current_pet_week_key(at_time);
	string season_key = current_pet_season_key(at_time);
	int now = at_time || time();
	if((string)record["daily_key"]!=day_key){
		record["daily_key"] = day_key;
		record["daily"] = (["hunt":0,"rift":0,"pve_fragments":0,
			"owner_revive":0,"opponents":({})]);
		changed = 1;
	}
	if((string)record["weekly_key"]!=week_key){
		record["weekly_key"] = week_key;
		record["weekly"] = (["rift_wins":0,"choice_claimed":0]);
		changed = 1;
	}
	if((string)record["season_key"]!=season_key){
		record["season_key"] = season_key;
		record["season"] = (["wins":0,"losses":0,"draws":0]);
		changed = 1;
	}
	foreach(indices((mapping)record["pending_rift_rewards"]),
	   string session_id){
		mapping reward = record["pending_rift_rewards"][session_id];
		if(!reward || (int)reward["expires_at"]<now){
			m_delete(record["pending_rift_rewards"],session_id);
			changed = 1;
		}
	}
	return changed;
}

private string resolve_pet_account(object player)
{
	string character_id;
	string account_id;
	if(!player || !functionp(player->query_name) ||
	   !functionp(player->query_account_owner))
		return "";
	character_id = player->query_name();
	account_id = player->query_account_owner();
	if(!valid_pet_userid(character_id) || !valid_pet_userid(account_id) ||
	   !ACCOUNT_CHARACTERD->account_owns_character(account_id,character_id))
		return "";
	return account_id;
}

private string new_pet_id_unlocked(mapping record)
{
	multiset(string) used = (<>);
	foreach((array)record["pets"],mapping pet)
		used[(string)pet["id"]] = 1;
	foreach((array)record["gear_inventory"],mapping gear)
		used[(string)gear["id"]] = 1;
	foreach(indices((mapping)record["rewarded_sessions"]),string session_id)
		used[session_id] = 1;
	for(int attempt=0;attempt<30;attempt++){
		string candidate = String.string2hex(
			Crypto.Random.random_string(32));
		if(!used[candidate])
			return candidate;
	}
	return "";
}

private int find_pet_index(array pets,string pet_id)
{
	for(int i=0;i<sizeof(pets);i++){
		if(mappingp(pets[i]) && pets[i]["id"]==pet_id)
			return i;
	}
	return -1;
}

private int find_species_index(array pets,string species)
{
	for(int i=0;i<sizeof(pets);i++){
		if(mappingp(pets[i]) && pets[i]["species"]==species)
			return i;
	}
	return -1;
}

private mapping(string:mixed) make_pet_instance_unlocked(mapping record,
	string species,string source)
{
	mapping info = shanhai_catalog[species];
	string pet_id = new_pet_id_unlocked(record);
	if(!info || pet_id=="")
		return ([]);
	return ([
		"id":pet_id,
		"species":species,
		"level":1,
		"star":1,
		"xp":0,
		"bond":1,
		"bond_xp":0,
		"skill_set":0,
		"skills":copy_value(info["skill_sets"][0]),
		"variants":({"原生"}),
		"equipment":([]),
		"equipment_bonus":(["life":0,"attack":0,"defense":0,
			"spirit":0,"speed":0]),
		"imprinted_skill":0,
		"source":source,
		"acquired_at":time(),
	]);
}

/** Authenticated map-worker ingress only: discard cross-process stale state. */
void invalidate_worker_account_cache(string account_id)
{
	if(MAP_WORKERD->query_node_role()!="worker" ||
	   !valid_pet_userid(account_id))
		return;
	object key = pet_lock->lock();
	m_delete(pet_cache,account_id);
	destruct(key);
}

void drop_test_pet_cache(string account_id)
{
	if(search(account_id,"testunit")==-1)
		return;
	object key = pet_lock->lock();
	m_delete(pet_cache,account_id);
	destruct(key);
}

void remove_test_pet_data(string account_id)
{
	string path;
	if(search(account_id,"testunit")==-1 || !valid_pet_userid(account_id))
		return;
	path = pet_file_path(account_id);
	object key = pet_lock->lock();
	m_delete(pet_cache,account_id);
	foreach(indices(rift_sessions),string team_id){
		mapping session = rift_sessions[team_id];
		int remove_session = 0;
		foreach((array)(session && session["participants"] || ({})),
		   string character_id){
			if(ACCOUNT_CHARACTERD->query_account_id_for_character(
			   character_id)==account_id){
				remove_session = 1;
				break;
			}
		}
		if(remove_session)
			m_delete(rift_sessions,team_id);
	}
	foreach(indices(rift_recruits),string leader_id)
		if(ACCOUNT_CHARACTERD->query_account_id_for_character(
		   leader_id)==account_id)
			m_delete(rift_recruits,leader_id);
	foreach(indices(duel_invites),string target_id){
		mapping invite = duel_invites[target_id];
		if(ACCOUNT_CHARACTERD->query_account_id_for_character(target_id)==
		   account_id || (invite && ACCOUNT_CHARACTERD->
		   query_account_id_for_character((string)invite["challenger_id"])==
		   account_id))
			m_delete(duel_invites,target_id);
	}
	rm(path);
	rm(path+".tmp");
	rm(path+".bak");
	rm(path+".bak.tmp");
	destruct(key);
}

#endif
