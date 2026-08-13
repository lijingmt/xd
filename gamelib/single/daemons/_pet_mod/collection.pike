/** 图鉴、唯一宠物、培养、独立材料栏与每日寻迹。 */

#ifndef XIAND_PET_COLLECTION_PIKE
#define XIAND_PET_COLLECTION_PIKE

private mapping(string:mixed) pet_result(int ok,string message)
{
	return (["ok":ok,"message":message]);
}

private void clear_pet_runtime(object player)
{
	if(!player)
		return;
	player["/tmp/wanling/pet_id"] = 0;
	player["/tmp/wanling/species"] = 0;
	player["/tmp/wanling/skill_set"] = 0;
	player["/tmp/wanling/pet_level"] = 0;
	player["/tmp/wanling/player_level"] = 0;
	player["/tmp/wanling/pet_star"] = 0;
	player["/tmp/wanling/pet_bond"] = 0;
	player["/tmp/wanling/pet_evolution"] = 0;
	player["/tmp/wanling/pet_evolution_name"] = 0;
	player["/tmp/wanling/pet_attributes"] = 0;
	player["/tmp/wanling/pet_power"] = 0;
	player["/tmp/wanling/pet_growth_percent"] = 0;
	player["/tmp/wanling/pet_pvp_growth_percent"] = 0;
	player["/tmp/wanling/pet_name"] = 0;
	player["/tmp/wanling/pet_polarity"] = 0;
	player["/tmp/wanling/pet_skills"] = 0;
	player["/tmp/wanling/pet_fusion"] = 0;
	player["/tmp/wanling/pet_equipment_bonus"] = 0;
	player["/tmp/wanling/imprinted_skill"] = 0;
	player["/tmp/wanling/assist_at"] = 0;
	player["/tmp/wanling/assist_seq"] = 0;
	player["/tmp/wanling/recent_assist"] = 0;
	player["/tmp/wanling/pvp_target"] = 0;
	player["/tmp/wanling/pvp_charge"] = 0;
	player["/tmp/wanling/pvp_uses"] = 0;
	player["/tmp/wanling/owner_revive_day_key"] = 0;
	player["/tmp/wanling/owner_revive_used"] = 0;
}

private void sync_pet_owner_revive_runtime_unlocked(object player,
	mapping record)
{
	if(!player || !mappingp(record) || !mappingp(record["daily"]))
		return;
	player["/tmp/wanling/owner_revive_day_key"] =
		(string)record["daily_key"];
	player["/tmp/wanling/owner_revive_used"] =
		(int)record["daily"]["owner_revive"];
}

private void sync_pet_runtime_unlocked(object player,mapping pet,
	void|int reset_combat)
{
	mapping attributes;
	mapping effective_pet;
	int star;
	if(!player || !mappingp(pet))
		return;
	effective_pet = copy_value(pet);
	effective_pet["level"] = query_pet_effective_level(player,
		(int)pet["level"]);
	star = (int)pet["star"];
	if(star<1)
		star = 1;
	attributes = query_pet_attributes(effective_pet);
	player["/tmp/wanling/pet_id"] = pet["id"];
	player["/tmp/wanling/species"] = pet["species"];
	player["/tmp/wanling/skill_set"] = pet["skill_set"];
	player["/tmp/wanling/pet_level"] = effective_pet["level"];
	player["/tmp/wanling/player_level"] = query_pet_level_max(player);
	player["/tmp/wanling/pet_star"] = star;
	player["/tmp/wanling/pet_bond"] = pet["bond"];
	player["/tmp/wanling/pet_evolution"] =
		query_pet_evolution_stage(star);
	player["/tmp/wanling/pet_evolution_name"] =
		query_pet_evolution_name(star);
	player["/tmp/wanling/pet_attributes"] = copy_value(attributes);
	player["/tmp/wanling/pet_power"] = (int)attributes["power"];
	player["/tmp/wanling/pet_growth_percent"] =
		query_pet_growth_percent(effective_pet,0);
	player["/tmp/wanling/pet_pvp_growth_percent"] =
		query_pet_growth_percent(effective_pet,1);
	player["/tmp/wanling/pet_name"] = mappingp(pet["fusion"]) &&
		(string)pet["fusion"]["name"]!="" ?
		(string)pet["fusion"]["name"] :
		(string)shanhai_catalog[(string)pet["species"]]["name"];
	player["/tmp/wanling/pet_polarity"] = query_pet_polarity(pet);
	player["/tmp/wanling/pet_skills"] = arrayp(pet["skills"]) ?
		copy_value((array)pet["skills"]) : copy_value((array)
		shanhai_catalog[(string)pet["species"]]["skill_sets"][
			(int)pet["skill_set"]]);
	player["/tmp/wanling/pet_fusion"] = mappingp(pet["fusion"]) ?
		copy_value((mapping)pet["fusion"]) : 0;
	player["/tmp/wanling/pet_equipment_bonus"] = mappingp(
		pet["equipment_bonus"]) ?
		copy_value((mapping)pet["equipment_bonus"]) :
		empty_pet_equipment_bonus();
	player["/tmp/wanling/imprinted_skill"] =
		mappingp(pet["imprinted_skill"]) ?
		copy_value((mapping)pet["imprinted_skill"]) : 0;
	if(reset_combat){
		player["/tmp/wanling/assist_at"] = 0;
		player["/tmp/wanling/recent_assist"] = 0;
		player["/tmp/wanling/pvp_target"] = 0;
		player["/tmp/wanling/pvp_charge"] = 0;
		player["/tmp/wanling/pvp_uses"] = 0;
	}
}

/**
 * Worker 收到新的账号缓存能力后，永久万灵谱已经可能被同账号的另一个
 * 人物修改。只清进程缓存不足以更新在线人物的临时战斗快照；这里从同一
 * 权威文件重建灵纹、拓印和装备增益。仍是同一只宠物时保留本场冷却与
 * PVP 充能，只有协战归属真的变化时才重置，避免刷新能力被用来刷技能。
 */
int refresh_pet_player_runtime(object player)
{
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	string character_id;
	string pet_id;
	string runtime_pet_id;
	object key;
	if(account_id==""){
		clear_pet_runtime(player);
		return 1;
	}
	character_id = player->query_name();
	runtime_pet_id = (string)(player["/tmp/wanling/pet_id"] || "");
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		refresh_pet_periods_unlocked(record);
		pet_id = (string)(record["active"][character_id] || "");
		int index = find_pet_index(record["pets"],pet_id);
		if(index>=0){
			sync_pet_runtime_unlocked(player,record["pets"][index],
				runtime_pet_id!=pet_id);
			sync_pet_owner_revive_runtime_unlocked(player,record);
		}
		else
			clear_pet_runtime(player);
	}
	else
		clear_pet_runtime(player);
	player["/tmp/wanling/runtime_stale"] = 0;
	destruct(key);
	return 1;
}

/** 网关鉴权阶段只做O(1)标记，避免普通请求立即读取宠物档案。 */
void mark_pet_player_runtime_stale(object player)
{
	if(player)
		player["/tmp/wanling/runtime_stale"] = 1;
}

private void refresh_pet_runtime_if_stale(object player)
{
	if(player && (int)player["/tmp/wanling/runtime_stale"])
		refresh_pet_player_runtime(player);
}

/** 人物升级、降级或转生后，首次读取协战状态时自动重算共享宠物。 */
private void refresh_pet_runtime_level_if_needed(object player)
{
	string account_id;
	string character_id;
	string pet_id;
	mapping(string:mixed)|zero record;
	object key;
	if(!player || (string)(player["/tmp/wanling/species"] || "")=="" ||
	   (int)player["/tmp/wanling/player_level"]==
		query_pet_level_max(player))
		return;
	account_id = resolve_pet_account(player);
	if(account_id==""){
		clear_pet_runtime(player);
		return;
	}
	character_id = player->query_name();
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		pet_id = (string)(record["active"][character_id] || "");
		int index = find_pet_index(record["pets"],pet_id);
		if(index>=0)
			sync_pet_runtime_unlocked(player,record["pets"][index],0);
		else
			clear_pet_runtime(player);
	}
	else
		clear_pet_runtime(player);
	destruct(key);
}

void reset_pet_combat_state(object player)
{
	if(!player)
		return;
	player["/tmp/wanling/pvp_target"] = 0;
	player["/tmp/wanling/pvp_charge"] = 0;
	player["/tmp/wanling/pvp_uses"] = 0;
}

private void add_pet_material_unlocked(mapping record,string material,
	int amount)
{
	mapping materials = record["materials"];
	int value;
	if(!has_index(empty_pet_materials(),material) || amount==0)
		return;
	value = (int)materials[material]+amount;
	if(value<0)
		value = 0;
	if(value>1000000000)
		value = 1000000000;
	materials[material] = value;
}

private mapping(string:mixed) acquire_pet_unlocked(mapping record,
	string species,string source)
{
	mapping result = pet_result(0,"未能缔结灵契。");
	int existing;
	mapping pet;
	if(!shanhai_catalog[species]){
		result["message"] = "万灵谱中没有这种异兽。";
		return result;
	}
	existing = find_species_index(record["pets"],species);
	if(existing>=0){
		add_pet_material_unlocked(record,"egg_fragment",10);
		result["ok"] = 1;
		result["duplicate"] = 1;
		result["message"] = "图鉴已经收录"+
			(string)shanhai_catalog[species]["name"]+
			"，重复灵契已化为10枚灵卵残片。";
		return result;
	}
	pet = make_pet_instance_unlocked(record,species,source);
	if(!sizeof(pet))
		return result;
	record["pets"] += ({pet});
	result = pet_result(1,"万灵谱收录了"+
		(string)shanhai_catalog[species]["name"]+"。");
	result["pet"] = copy_value(pet);
	return result;
}

mapping(string:mixed) query_pet_state(object player)
{
	mapping result = pet_result(0,"万灵谱暂不可用。");
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(!record)
		result["message"] = "万灵谱数据校验失败，已停止操作以保护灵宠。";
	else{
		int changed = refresh_pet_periods_unlocked(record);
		if(changed && (int)record["persisted"] &&
		   !(int)record["migration_pending"])
			save_pet_record_unlocked(record);
		result = copy_value(record);
		m_delete(result,"migration_pending");
		array enriched_pets = ({});
		foreach((array)record["pets"],mapping pet)
			enriched_pets += ({enrich_pet_view(
				enrich_pet_equipment_view_unlocked(record,pet),player)});
		result["pets"] = enriched_pets;
		result["ok"] = 1;
		result["message"] = "";
		result["character_id"] = player->query_name();
		result["starter_level"] = PET_STARTER_LEVEL;
		result["level_max"] = query_pet_level_max(player);
		int catalog_total = 0;
		foreach(shanhai_catalog;string catalog_species;mapping catalog_info)
			if(!(int)catalog_info["hidden"] ||
			   find_species_index(record["pets"],catalog_species)>=0)
				catalog_total++;
		result["catalog_total"] = catalog_total;
		result["collection_count"] = sizeof((array)record["pets"]);
		result["weekly_boss"] = query_weekly_boss_species();
	}
	destruct(key);
	return result;
}

/** 本命灵伴共鸣只读入口：不刷新日周周期，也不触发共享宠物写盘。 */
int query_shared_pet_collection_count_read_only(object player)
{
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	int count = 0;
	object key;
	if(account_id=="")
		return 0;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record)
		count = sizeof((array)record["pets"]);
	destruct(key);
	return count;
}

mapping(string:mixed) choose_starter_pet(object player,string species)
{
	mapping result = pet_result(0,"新手灵契没有生效。");
	string account_id = resolve_pet_account(player);
	string character_id;
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	if(player->query_level()<PET_STARTER_LEVEL){
		result["message"] = "达到15级后才能在万灵谱选择第一位伙伴。";
		return result;
	}
	if(search(starter_species,species)==-1){
		result["message"] = "新手灵契只能从当康、鹿蜀、文鳐鱼中选择。";
		return result;
	}
	character_id = player->query_name();
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(!record)
		result["message"] = "万灵谱数据异常，本次没有建立灵契。";
	else if((int)record["starter_claimed"])
		result["message"] = "这个注册账号已经领取过第一位万灵伙伴。";
	else{
		result = acquire_pet_unlocked(record,species,"starter");
		if(result["ok"]){
			int pet_index = find_pet_index(record["pets"],
				(string)result["pet"]["id"]);
			mapping pet = pet_index>=0 ? record["pets"][pet_index] : ([]);
			array starter_gear = pet_index>=0 ?
				grant_starter_pet_gear_unlocked(record,pet) : ({});
			if(sizeof(starter_gear)!=3){
				result = pet_result(0,
					"初契装备建立失败，本次灵契没有生效。");
				if(pet_index>=0)
					record["pets"] -= ({pet});
			}
			else
				result["pet"] = copy_value(pet);
		}
		if(result["ok"]){
			mapping pet = record["pets"][find_species_index(record["pets"],
				species)];
			record["starter_claimed"] = 1;
			record["active"][character_id] = pet["id"];
			add_pet_material_unlocked(record,"spirit_dew",12);
			add_pet_material_unlocked(record,"bond_token",2);
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record)){
				sync_pet_runtime_unlocked(player,pet,1);
				sync_pet_owner_revive_runtime_unlocked(player,record);
				result["message"] +=
					"它已设为当前协战伙伴，并获赠初契三件套、12滴灵露与2枚同心叶。";
			}
			else
				result = pet_result(0,"万灵谱保存失败，本次灵契没有生效。");
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) set_active_pet(object player,string pet_id)
{
	mapping result = pet_result(0,"未能调整协战伙伴。");
	string account_id = resolve_pet_account(player);
	string character_id;
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	if(player->query_in_combat && player->query_in_combat())
		return pet_result(0,"交战中不能更换或暂停协战伙伴。 ");
	character_id = player->query_name();
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(!record)
		result["message"] = "万灵谱数据异常，本次没有修改。";
	else if(pet_id=="none"){
		m_delete(record["active"],character_id);
		record["revision"] = (int)record["revision"]+1;
		if(save_pet_record_unlocked(record)){
			clear_pet_runtime(player);
			result = pet_result(1,"当前角色已暂停灵宠协战，图鉴与培养不会丢失。");
		}
	}
	else{
		int pet_index = find_pet_index(record["pets"],pet_id);
		string occupied_by = "";
		if(pet_index<0)
			result["message"] = "万灵谱中没有这只灵宠，请刷新后重试。";
		else{
			foreach(record["active"];string other_character;mixed other_pet){
				if(other_character!=character_id && other_pet==pet_id){
					occupied_by = other_character;
					break;
				}
			}
			if(occupied_by!="" && find_player(occupied_by))
				result["message"] = "这只灵宠正陪伴同账号的在线角色，不能同时协战。";
			else{
				if(occupied_by!="")
					m_delete(record["active"],occupied_by);
				record["active"][character_id] = pet_id;
				record["revision"] = (int)record["revision"]+1;
					if(save_pet_record_unlocked(record)){
						mapping pet = record["pets"][pet_index];
						sync_pet_runtime_unlocked(player,pet,1);
						sync_pet_owner_revive_runtime_unlocked(player,record);
					result = pet_result(1,(string)shanhai_catalog[
						(string)pet["species"]]["name"]+
						"已成为当前协战伙伴。");
				}
				else
					result["message"] = "万灵谱保存失败，本次没有修改。";
			}
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) set_pet_duel_team(object player,array(string) pet_ids)
{
	mapping result = pet_result(0,"论道编队没有保存。");
	string account_id = resolve_pet_account(player);
	string character_id;
	mapping(string:mixed)|zero record;
	multiset(string) seen = (<>);
	object key;
	if(account_id=="" || !arrayp(pet_ids) || sizeof(pet_ids)>3)
		return result;
	character_id = player->query_name();
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(!record)
		result["message"] = "万灵谱数据异常，本次没有修改。";
	else{
		int valid = 1;
		foreach(pet_ids,string pet_id){
			if(seen[pet_id] || find_pet_index(record["pets"],pet_id)<0){
				valid = 0;
				break;
			}
			seen[pet_id] = 1;
		}
		if(!valid)
			result["message"] = "论道编队含有重复或不属于本账号的灵宠。";
		else{
			record["duel_teams"][character_id] = pet_ids+({});
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record))
				result = pet_result(1,"三宠论道编队已经保存；不足三只时会借用标准试炼灵宠补位。 ");
			else
				result["message"] = "万灵谱保存失败，本次没有修改。";
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) train_pet_levels(object player,string pet_id,
	int requested)
{
	mapping result = pet_result(0,"本次培养没有生效。");
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(requested<1 || requested>10)
		return pet_result(0,"每次只能培养1级或连续培养10级。");
	if(account_id=="")
		return result;
	if(player->query_in_combat && player->query_in_combat())
		return pet_result(0,"交战中不能培养灵宠。 ");
	if(requested>1 && VIPD->query_active_vip_level(player)<2)
		return pet_result(0,"连续培养10级需要VIP2（黄金会员）；"+
			"普通培养1级仍可使用。");
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		int index = find_pet_index(record["pets"],pet_id);
		if(index<0)
			result["message"] = "找不到这只灵宠。";
		else{
			mapping pet = record["pets"][index];
			int level_max = query_pet_level_max(player);
			int level = (int)pet["level"];
			int start_level = level;
			int total_cost = 0;
			int trained = 0;
			int available = (int)record["materials"]["spirit_dew"];
			int next_cost = 2+level/5;
			if(level>=level_max)
				result["message"] = level>level_max ?
					"这只共享宠物的培养进度已保留至Lv."+
					level+"；当前角色只按Lv."+level_max+
					"生效，人物升级后自动解锁。" :
					"灵宠有效等级已与当前角色Lv."+
					level_max+"同步；人物升级后才能继续培养。";
			else{
				while(trained<requested && level<level_max){
					next_cost = 2+level/5;
					if(total_cost+next_cost>available)
						break;
					total_cost += next_cost;
					level++;
					trained++;
				}
				if(trained<=0)
					result["message"] = "灵露不足，下一次培养需要"+
						next_cost+"滴。";
				else{
					add_pet_material_unlocked(record,"spirit_dew",-total_cost);
					pet["level"] = level;
					record["revision"] = (int)record["revision"]+1;
					if(save_pet_record_unlocked(record)){
						if(record["active"][player->query_name()]==pet_id)
							sync_pet_runtime_unlocked(player,pet,0);
						string pet_name = (string)shanhai_catalog[
							(string)pet["species"]]["name"];
						if(mappingp(pet["fusion"]) &&
						   (string)pet["fusion"]["name"]!="")
							pet_name = (string)pet["fusion"]["name"];
						if(requested==1)
							result = pet_result(1,pet_name+"成长到"+
								level+"级，消耗"+total_cost+"滴灵露。");
						else{
							result = pet_result(1,pet_name+"从"+start_level+
								"级成长到"+level+"级，共提升"+trained+
								"级，消耗"+total_cost+"滴灵露。");
							if(trained<requested)
								result["message"] += level>=level_max ?
									"已与当前人物等级同步。" :
									"剩余灵露不足，已在安全档位停止。";
						}
						result["level"] = pet["level"];
						result["trained"] = trained;
						result["cost"] = total_cost;
					}
				}
			}
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) train_pet_level(object player,string pet_id)
{
	return train_pet_levels(player,pet_id,1);
}

mapping(string:mixed) upgrade_pet_star(object player,string pet_id)
{
	mapping result = pet_result(0,"本次升星没有生效。 ");
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	if(player->query_in_combat && player->query_in_combat())
		return pet_result(0,"交战中不能为灵宠升星。 ");
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		int index = find_pet_index(record["pets"],pet_id);
		if(index<0)
			result["message"] = "找不到这只灵宠。";
		else{
			mapping pet = record["pets"][index];
			int star = (int)pet["star"];
			int cost = query_pet_star_cost(star);
			int old_evolution = query_pet_evolution_stage(star);
			if(star>=PET_STAR_MAX)
				result["message"] = "灵宠已经达到十星圆满。";
			else if(cost<=0)
				result["message"] = "当前星级数据异常，已停止操作。";
			else if((int)record["materials"]["egg_fragment"]<cost)
				result["message"] = "灵卵残片不足，本次升星需要"+
					cost+"枚。";
			else{
				add_pet_material_unlocked(record,"egg_fragment",-cost);
				pet["star"] = star+1;
				record["revision"] = (int)record["revision"]+1;
				if(save_pet_record_unlocked(record)){
					int new_star = (int)pet["star"];
					int new_evolution = query_pet_evolution_stage(new_star);
					if(record["active"][player->query_name()]==pet_id)
						sync_pet_runtime_unlocked(player,pet,0);
					result = pet_result(1,(string)shanhai_catalog[
						(string)pet["species"]]["name"]+"升至"+new_star+
						"星，消耗"+cost+"枚灵卵残片。 ");
					if(new_evolution>old_evolution)
						result["message"] += "灵契共鸣，进化为"+
							query_pet_evolution_name(new_star)+"！";
					result["star"] = new_star;
					result["evolution"] = new_evolution;
				}
			}
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) deepen_pet_bond(object player,string pet_id)
{
	mapping result = pet_result(0,"本次羁绊交流没有生效。");
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	if(player->query_in_combat && player->query_in_combat())
		return pet_result(0,"交战中不能深化灵宠羁绊。 ");
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		int index = find_pet_index(record["pets"],pet_id);
		if(index<0)
			result["message"] = "找不到这只灵宠。";
		else{
			mapping pet = record["pets"][index];
			int bond = (int)pet["bond"];
			if(bond>=PET_BOND_MAX)
				result["message"] = "这只灵宠已经达到五阶知己羁绊。";
			else if((int)record["materials"]["bond_token"]<bond)
				result["message"] = "同心叶不足，本阶需要"+bond+"枚。";
			else{
				add_pet_material_unlocked(record,"bond_token",-bond);
				pet["bond"] = bond+1;
				pet["bond_xp"] = 0;
				record["revision"] = (int)record["revision"]+1;
				if(save_pet_record_unlocked(record)){
					if(record["active"][player->query_name()]==pet_id)
						sync_pet_runtime_unlocked(player,pet,0);
					result = pet_result(1,(string)shanhai_catalog[
						(string)pet["species"]]["name"]+"与你的羁绊升至"+
						(int)pet["bond"]+"阶。新的山海小传已经解锁。");
				}
			}
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) reset_pet_skills(object player,string pet_id)
{
	mapping result = pet_result(0,"灵纹没有调整。");
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	if(player->query_in_combat && player->query_in_combat())
		return pet_result(0,"交战中不能轮换灵纹。 ");
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		int index = find_pet_index(record["pets"],pet_id);
		if(index<0)
			result["message"] = "找不到这只灵宠。";
		else if((int)record["materials"]["skill_rune"]<1)
			result["message"] = "你当前有0枚灵纹符，轮换需要1枚。"+
				"灵纹符不进入人物背包；每周平复3次万灵裂隙后，"+
				"可在『今日修行→本周目标』三选一领取2枚。";
		else{
			mapping pet = record["pets"][index];
			mapping info = shanhai_catalog[(string)pet["species"]];
			int next_set = ((int)pet["skill_set"]+1)%3;
			add_pet_material_unlocked(record,"skill_rune",-1);
			pet["skill_set"] = next_set;
			pet["skills"] = copy_value(info["skill_sets"][next_set]);
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record)){
				if(record["active"][player->query_name()]==pet_id)
					sync_pet_runtime_unlocked(player,pet,0);
				result = pet_result(1,(string)info["name"]+
					"的三枚灵纹已切换；这是确定轮换，不会随机洗坏。 ");
				result["skills"] = copy_value(pet["skills"]);
			}
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) start_pet_hunt(object player)
{
	mapping result = pet_result(0,"今日寻迹没有开始。");
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	if(player->query_level()<PET_STARTER_LEVEL){
		result["message"] = "达到15级并缔结第一只灵宠后开放寻迹。";
		return result;
	}
	if(!(string)(player["/tmp/wanling/pet_id"] || "")){
		result["message"] = "请先在万灵谱设置当前协战伙伴，再开始今日寻迹。";
		return result;
	}
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		refresh_pet_periods_unlocked(record);
		if(!(int)record["starter_claimed"])
			result["message"] = "请先在万灵谱缔结第一只灵宠。";
		else if((int)record["daily"]["hunt"]>=4)
			result["message"] = "今日灵宠寻迹已经完成，明日会出现新线索。";
		else if((int)record["daily"]["hunt"]>0){
			result = pet_result(1,"寻迹进行中：击败3只等级不低于你当前等级减5的普通怪物。 ");
			result["progress"] = (int)record["daily"]["hunt"]-1;
		}
		else{
			record["daily"]["hunt"] = 1;
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record)){
				result = pet_result(1,"今日寻迹已开始：带着协战伙伴击败3只等级不低于你当前等级减5的普通怪物。 ");
				result["progress"] = 0;
			}
		}
	}
	destruct(key);
	return result;
}

/** 只从NPC真实死亡奖励路径调用；城战、召唤物和低级碾压不计数。 */
mapping(string:mixed) record_pet_hunt_kill(object player,object npc)
{
	mapping result = (["ok":0,"completed":0]);
	if(SPIRIT_COMPANIOND->query_pet_battle_source(player)!="shared")
		return result;
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="" || !npc || !npc->is || !npc->is("npc") ||
	   !(string)(player["/tmp/wanling/pet_id"] || "") ||
	   SUMMOND->query_combat_credit_owner(npc)!=npc ||
	   player->query_level()-npc->query_level()>5)
		return result;
	if(npc->query_npc_type &&
	   search(({"city_keeper","city_guarder","city_lord"}),
		(string)npc->query_npc_type())!=-1)
		return result;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		mapping credited_accounts = mappingp(
			npc["/tmp/wanling/hunt_accounts"]) ?
			npc["/tmp/wanling/hunt_accounts"] : ([]);
		if(credited_accounts[account_id]){
			destruct(key);
			return result;
		}
		refresh_pet_periods_unlocked(record);
		int progress = (int)record["daily"]["hunt"];
		if(progress>=1 && progress<4){
			progress++;
			record["daily"]["hunt"] = progress;
			if(progress==4){
				add_pet_material_unlocked(record,"spirit_mark",2);
				add_pet_material_unlocked(record,"spirit_dew",8);
				add_pet_material_unlocked(record,"egg_fragment",2);
				add_pet_material_unlocked(record,"bond_token",1);
				result["completed"] = 1;
			}
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record)){
				credited_accounts[account_id] = 1;
				npc["/tmp/wanling/hunt_accounts"] = credited_accounts;
				result["ok"] = 1;
				result["progress"] = progress-1;
				if(result["completed"])
					tell_object(player,"【万灵寻迹完成】获得2枚灵印、8滴灵露、2枚灵卵残片和1枚同心叶。\n[查看今日修行:daily_cultivation]\n");
				else
					tell_object(player,"【万灵寻迹】线索进度 "+
						(progress-1)+"/3。\n");
			}
		}
	}
	destruct(key);
	return result;
}

/**
 * 真实NPC死亡时给当前协战宠物增加独立历练并自动连续升级。
 *
 * 历练不读取人物经验、经验药或VIP经验倍率，避免付费倍率放大宠物战力；
 * 同一只死亡NPC按宠物ID去重，使同账号多角色各自携带不同宠物时仍可成长。
 */
mapping(string:mixed) record_pet_combat_xp(object player,object npc)
{
	mapping result = (["ok":0,"xp_gain":0,"levels_gained":0]);
	if(SPIRIT_COMPANIOND->query_pet_battle_source(player)!="shared")
		return result;
	string account_id = resolve_pet_account(player);
	string character_id;
	string pet_id;
	mapping(string:mixed)|zero record;
	mapping credited_pets;
	object key;
	int player_level;
	int npc_level;
	int effective_level;
	int is_dungeon = 0;
	int is_boss = 0;
	int xp_gain;
	if(account_id=="" || !player || !npc || !npc->is ||
	   !npc->is("npc") ||
	   SUMMOND->query_combat_credit_owner(npc)!=npc)
		return result;
	player_level = player->query_level();
	npc_level = npc->query_level();
	if(player_level<PET_STARTER_LEVEL || npc_level<1 ||
	   player_level-npc_level>5)
		return result;
	if(npc->query_npc_type &&
	   search(({"city_keeper","city_guarder","city_lord"}),
		(string)npc->query_npc_type())!=-1)
		return result;
	if((string)(player->fb_id || "")!="" &&
	   FBD->query_fb_memebers((string)player->fb_id,
		player->query_name()))
		is_dungeon = 1;
	if((int)(npc->_boss || 0)>0)
		is_boss = 1;
	effective_level = npc_level;
	if(effective_level>player_level+5)
		effective_level = player_level+5;
	xp_gain = 15+effective_level;
	if(is_dungeon && is_boss)
		xp_gain *= 4;
	else if(is_boss)
		xp_gain *= 3;
	else if(is_dungeon)
		xp_gain *= 2;
	character_id = player->query_name();
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record && (int)record["starter_claimed"]){
		pet_id = (string)(record["active"][character_id] || "");
		int index = find_pet_index(record["pets"],pet_id);
		int level_max = query_pet_level_max(player);
		credited_pets = mappingp(npc["/tmp/wanling/xp_pet_ids"]) ?
			npc["/tmp/wanling/xp_pet_ids"] : ([]);
		if(index>=0 && !credited_pets[pet_id] &&
		   (int)record["pets"][index]["level"]<level_max){
			mapping pet = record["pets"][index];
			xp_gain = xp_gain*(100+
				query_pet_equipment_xp_bonus_unlocked(record,pet))/100;
			int old_level = (int)pet["level"];
			int level = old_level;
			int xp = (int)pet["xp"]+xp_gain;
			int need = query_pet_level_xp_need(level);
			while(level<level_max && need>0 && xp>=need){
				xp -= need;
				level++;
				need = query_pet_level_xp_need(level);
			}
			if(level>=level_max)
				xp = 0;
			pet["level"] = level;
			pet["xp"] = xp;
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record)){
				credited_pets[pet_id] = 1;
				npc["/tmp/wanling/xp_pet_ids"] = credited_pets;
				sync_pet_runtime_unlocked(player,pet,0);
				result["ok"] = 1;
				result["xp_gain"] = xp_gain;
				result["old_level"] = old_level;
				result["level"] = level;
				result["levels_gained"] = level-old_level;
				result["xp"] = xp;
				result["xp_need"] = need;
				if(level>old_level){
					string pet_name = mappingp(pet["fusion"]) &&
						(string)pet["fusion"]["name"]!="" ?
						(string)pet["fusion"]["name"] :
						(string)shanhai_catalog[
							(string)pet["species"]]["name"];
					string progress = level>=level_max ?
						"已与当前人物等级同步" :
						"当前历练 "+xp+"/"+need;
					tell_object(player,"【灵宠自动成长】"+pet_name+
						"从Lv."+old_level+"升至Lv."+level+
						"（连升"+(level-old_level)+"级），"+
						progress+"。\n[查看万灵谱:pet]\n");
				}
			}
		}
	}
	destruct(key);
	return result;
}

private mapping(string:mixed) record_pet_pve_fragment_unlocked(
	object player,object npc,int forced_roll)
{
	mapping result = (["ok":0,"dropped":0,"chance":0,
		"source":"普通怪物","daily_cap":PET_PVE_FRAGMENT_DAILY_CAP]);
	if(SPIRIT_COMPANIOND->query_pet_battle_source(player)!="shared")
		return result;
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	mapping credited_accounts;
	object key;
	int chance = 4;
	int is_dungeon = 0;
	int is_boss = 0;
	int roll;
	if(account_id=="" || !npc || !npc->is || !npc->is("npc") ||
	   SUMMOND->query_combat_credit_owner(npc)!=npc ||
	   player->query_level()<PET_STARTER_LEVEL ||
	   player->query_level()-npc->query_level()>5)
		return result;
	if(npc->query_npc_type &&
	   search(({"city_keeper","city_guarder","city_lord"}),
		(string)npc->query_npc_type())!=-1)
		return result;
	if((string)(player->fb_id || "")!="" &&
	   FBD->query_fb_memebers((string)player->fb_id,
		player->query_name()))
		is_dungeon = 1;
	if((int)(npc->_boss || 0)>0)
		is_boss = 1;
	if(is_dungeon && is_boss){
		chance = 50;
		result["source"] = "副本首领";
	}
	else if(is_boss){
		chance = 30;
		result["source"] = "首领";
	}
	else if(is_dungeon){
		chance = 12;
		result["source"] = "副本怪物";
	}
	result["chance"] = chance;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		refresh_pet_periods_unlocked(record);
		credited_accounts = mappingp(npc["/tmp/wanling/pve_accounts"]) ?
			npc["/tmp/wanling/pve_accounts"] : ([]);
		if(!credited_accounts[account_id] &&
		   (int)record["starter_claimed"] &&
		   (int)record["daily"]["pve_fragments"]<
			PET_PVE_FRAGMENT_DAILY_CAP){
			credited_accounts[account_id] = 1;
			npc["/tmp/wanling/pve_accounts"] = credited_accounts;
			roll = forced_roll>=0 ? forced_roll : random(100);
			if(roll<chance){
				add_pet_material_unlocked(record,"egg_fragment",1);
				record["daily"]["pve_fragments"] =
					(int)record["daily"]["pve_fragments"]+1;
				record["revision"] = (int)record["revision"]+1;
				if(save_pet_record_unlocked(record)){
					result["ok"] = 1;
					result["dropped"] = 1;
					result["daily"] =
						(int)record["daily"]["pve_fragments"];
					tell_object(player,"【万灵残片】从"+
						(string)result["source"]+"身上发现1枚灵卵残片（今日战斗获取 "+
						(int)result["daily"]+"/"+
						PET_PVE_FRAGMENT_DAILY_CAP+"）。\n");
				}
			}
			else
				result["ok"] = 1;
		}
	}
	destruct(key);
	return result;
}

/**
 * 70级以上真实首领的账号级隐藏灵契。世界首领0.02%，副本首领
 * 0.05%，每500次合格首领必定收录。同一NPC对同一账号只结算
 * 一次；兑换、残片孵化和融合均无法绕过这条获取链。
 */
private void append_hidden_luan_audit(object player,object npc,
	string account_id,string outcome,string reason,int chance,int roll,
	int pity_before,int pity_after)
{
	if(!player || !npc)
		return;
	ASYNC_IOD->append_log(ROOT+"/log/pet_hidden_drop_audit.log",
		sprintf("%d|account=%s|character=%s|outcome=%s|reason=%s|"+
			"player_level=%d|npc_level=%d|boss=%d|chance=%d|roll=%d|"+
			"pity_before=%d|pity_after=%d\n",
			time(),account_id,player->query_name(),outcome,reason,
			player->query_level(),npc->query_level(),(int)(npc->_boss || 0),
			chance,roll,pity_before,pity_after));
}

private mapping(string:mixed) record_hidden_luan_drop_unlocked(
	object player,object npc,int forced_roll)
{
	mapping result = (["ok":0,"eligible":0,"dropped":0,"chance":0,
		"pity":0,"pity_max":PET_HIDDEN_LUAN_PITY,"audit_reason":""]);
	string account_id = player ? resolve_pet_account(player) : "";
	mapping(string:mixed)|zero record;
	mapping credited_accounts;
	object key;
	int is_dungeon = 0;
	int chance;
	int roll;
	int pity_before = -1;
	int pity_after = -1;
	if(!player || !npc || !npc->is || !npc->is("npc") ||
	   (int)(npc->_boss || 0)<=0)
		return result;
	if(account_id==""){
		result["audit_reason"] = "invalid_account";
		append_hidden_luan_audit(player,npc,account_id,"rejected",
			(string)result["audit_reason"],0,-1,-1,-1);
		return result;
	}
	if(SUMMOND->query_combat_credit_owner(npc)!=npc){
		result["audit_reason"] = "summon_or_invalid_boss";
		append_hidden_luan_audit(player,npc,account_id,"rejected",
			(string)result["audit_reason"],0,-1,-1,-1);
		return result;
	}
	if(npc->query_level()<70){
		result["audit_reason"] = "npc_level_below_70";
		append_hidden_luan_audit(player,npc,account_id,"rejected",
			(string)result["audit_reason"],0,-1,-1,-1);
		return result;
	}
	if(player->query_level()<70){
		result["audit_reason"] = "player_level_below_70";
		append_hidden_luan_audit(player,npc,account_id,"rejected",
			(string)result["audit_reason"],0,-1,-1,-1);
		return result;
	}
	if(player->query_level()-npc->query_level()>5){
		result["audit_reason"] = "level_gap_over_5";
		append_hidden_luan_audit(player,npc,account_id,"rejected",
			(string)result["audit_reason"],0,-1,-1,-1);
		return result;
	}
	if(npc->query_npc_type &&
	   search(({"city_keeper","city_guarder","city_lord"}),
		(string)npc->query_npc_type())!=-1){
		result["audit_reason"] = "city_npc_excluded";
		append_hidden_luan_audit(player,npc,account_id,"rejected",
			(string)result["audit_reason"],0,-1,-1,-1);
		return result;
	}
	if((string)(player->fb_id || "")!="" &&
	   FBD->query_fb_memebers((string)player->fb_id,
		player->query_name()))
		is_dungeon = 1;
	chance = is_dungeon ? PET_HIDDEN_LUAN_DUNGEON_CHANCE :
		PET_HIDDEN_LUAN_WORLD_CHANCE;
	result["eligible"] = 1;
	result["chance"] = chance;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		pity_before = (int)record["hidden_luan_pity"];
		credited_accounts = mappingp(npc["/tmp/wanling/hidden_accounts"]) ?
			npc["/tmp/wanling/hidden_accounts"] : ([]);
		if(find_species_index(record["pets"],PET_HIDDEN_LUAN_SPECIES)>=0){
			result["ok"] = 1;
			result["owned"] = 1;
			result["pity"] = (int)record["hidden_luan_pity"];
			result["audit_reason"] = "already_owned";
			pity_after = (int)record["hidden_luan_pity"];
			append_hidden_luan_audit(player,npc,account_id,"ignored",
				(string)result["audit_reason"],chance,-1,pity_before,pity_after);
		}
		else if((int)record["starter_claimed"] &&
		   !credited_accounts[account_id]){
			int next_pity = (int)record["hidden_luan_pity"]+1;
			roll = forced_roll>=0 ? forced_roll : random(10000);
			if(next_pity>=PET_HIDDEN_LUAN_PITY || roll<chance){
				string source = is_dungeon ? "hidden_dungeon_boss" :
					"hidden_world_boss";
				if(next_pity>=PET_HIDDEN_LUAN_PITY)
					source += "_pity";
				mapping acquired = acquire_pet_unlocked(record,
					PET_HIDDEN_LUAN_SPECIES,source);
				if(acquired["ok"]){
					record["hidden_luan_pity"] = 0;
					result["dropped"] = 1;
					result["pet"] = copy_value(acquired["pet"]);
					result["audit_reason"] = next_pity>=PET_HIDDEN_LUAN_PITY ?
						"pity_guarantee" : "random_drop";
				}
				else{
					next_pity = (int)record["hidden_luan_pity"];
					result["audit_reason"] = "acquire_failed";
				}
			}
			else
				result["audit_reason"] = "roll_miss";
			if(!result["dropped"])
				record["hidden_luan_pity"] = next_pity;
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record)){
				credited_accounts[account_id] = 1;
				npc["/tmp/wanling/hidden_accounts"] = credited_accounts;
				result["ok"] = 1;
				result["pity"] = (int)record["hidden_luan_pity"];
				pity_after = (int)record["hidden_luan_pity"];
				append_hidden_luan_audit(player,npc,account_id,
					result["dropped"] ? "dropped" : "counted",
					(string)result["audit_reason"],chance,roll,
					pity_before,pity_after);
				if(result["dropped"]){
					tell_object(player,"【隐藏灵契】首领消散时落下一枚五采灵羽，鸾鸟以回生羽与你缔结灵契！\n[查看万灵谱:pet]\n");
					ASYNC_IOD->append_log(ROOT+"/log/pet_hidden_drop.log",
						time()+"|"+account_id+"|"+player->query_name()+
						"|"+(is_dungeon ? "dungeon" : "world")+
						"|roll="+roll+"|pity="+next_pity+"\n");
				}
			}
			else{
				result["ok"] = 0;
				result["dropped"] = 0;
				result["audit_reason"] = "save_failed";
				m_delete(result,"pet");
				append_hidden_luan_audit(player,npc,account_id,"failed",
					(string)result["audit_reason"],chance,roll,
					pity_before,pity_before);
			}
		}
		else if(!(int)record["starter_claimed"]){
			result["audit_reason"] = "starter_not_claimed";
			append_hidden_luan_audit(player,npc,account_id,"rejected",
				(string)result["audit_reason"],chance,-1,pity_before,pity_before);
		}
		else{
			result["ok"] = 1;
			result["pity"] = (int)record["hidden_luan_pity"];
			result["audit_reason"] = "duplicate_npc";
			append_hidden_luan_audit(player,npc,account_id,"ignored",
				(string)result["audit_reason"],chance,-1,pity_before,pity_before);
		}
	}
	else{
		result["audit_reason"] = "record_load_failed";
		append_hidden_luan_audit(player,npc,account_id,"failed",
			(string)result["audit_reason"],chance,-1,-1,-1);
	}
	destruct(key);
	return result;
}

/** 普通同级怪、副本怪和BOSS都可独立产出残片，并按账号设置每日上限。 */
mapping(string:mixed) record_pet_pve_kill(object player,object npc)
{
	mapping result = record_pet_pve_fragment_unlocked(player,npc,-1);
	result["hidden_pet"] = record_hidden_luan_drop_unlocked(player,npc,-1);
	return result;
}

mapping(string:mixed) test_record_pet_pve_kill(object player,object npc,
	int forced_roll)
{
	string account_id = resolve_pet_account(player);
	if(search(account_id,"testunit")==-1 || forced_roll<0 ||
	   forced_roll>99)
		return (["ok":0,"dropped":0]);
	return record_pet_pve_fragment_unlocked(player,npc,forced_roll);
}

mapping(string:mixed) test_record_hidden_luan_drop(object player,object npc,
	int forced_roll)
{
	string account_id = resolve_pet_account(player);
	if(search(account_id,"testunit")==-1 || forced_roll<0 ||
	   forced_roll>9999)
		return (["ok":0,"dropped":0]);
	return record_hidden_luan_drop_unlocked(player,npc,forced_roll);
}

int test_set_hidden_luan_pity(object player,int pity)
{
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	int ok = 0;
	if(search(account_id,"testunit")==-1 || pity<0 ||
	   pity>=PET_HIDDEN_LUAN_PITY)
		return 0;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		record["hidden_luan_pity"] = pity;
		record["revision"] = (int)record["revision"]+1;
		ok = save_pet_record_unlocked(record);
	}
	destruct(key);
	return ok;
}

private int pet_is_referenced_unlocked(mapping record,string pet_id)
{
	foreach((mapping)record["active"];string active_character;
	   mixed active_id)
		if((string)active_id==pet_id)
			return 1;
	foreach((mapping)record["duel_teams"];string duel_character;
	   mixed raw_team)
		if(arrayp(raw_team) && search((array)raw_team,pet_id)!=-1)
			return 1;
	return 0;
}

private int query_fusion_generation(mapping pet)
{
	if(mappingp(pet["fusion"]))
		return (int)pet["fusion"]["generation"];
	return 0;
}

private mapping(string:mixed) pet_fusion_preview_unlocked(mapping record,
	string first_id,string second_id,int vip_level,object player)
{
	mapping result = pet_result(0,"这两只灵宠暂时不能合成。");
	int first_index = find_pet_index(record["pets"],first_id);
	int second_index = find_pet_index(record["pets"],second_id);
	if(first_id==second_id || first_index<0 || second_index<0){
		result["message"] = "请选择两只不同且属于本账号的灵宠。";
		return result;
	}
	mapping first = record["pets"][first_index];
	mapping second = record["pets"][second_index];
	if((string)first["species"]==PET_HIDDEN_LUAN_SPECIES ||
	   (string)second["species"]==PET_HIDDEN_LUAN_SPECIES){
		result["message"] = "隐藏灵契鸾鸟不能作为合成材料。";
		return result;
	}
	string first_polarity = query_pet_polarity(first);
	string second_polarity = query_pet_polarity(second);
	int generation = query_fusion_generation(first);
	int second_generation = query_fusion_generation(second);
	if(second_generation>generation)
		generation = second_generation;
	generation++;
	if(first_polarity==second_polarity){
		result["message"] = "灵宠合成必须一阴一阳；当前两只均为"+
			query_pet_polarity_name(first_polarity)+"属。";
		return result;
	}
	if(generation>3){
		result["message"] = "三代融合灵契已经稳定，不能继续合成。";
		return result;
	}
	if(pet_is_referenced_unlocked(record,first_id) ||
	   pet_is_referenced_unlocked(record,second_id)){
		result["message"] = "出战中或论道编队中的灵宠不能合成，请先取消协战并移出编队。";
		return result;
	}
	int star_bonus = (int)first["star"]+(int)second["star"];
	int success_chance;
	if(star_bonus>20)
		star_bonus = 20;
	if((int)record["fusion_pity"]>=5)
		success_chance = 100;
	else{
		success_chance = 55+star_bonus+
			(int)record["fusion_pity"]*8;
		if(success_chance>90)
			success_chance = 90;
	}
	result = pet_result(1,"阴阳灵契可以合成。");
	result["first"] = enrich_pet_view(first,player);
	result["second"] = enrich_pet_view(second,player);
	result["success_chance"] = success_chance;
	result["success_cost"] = 10;
	result["failure_cost"] = vip_level>=3 ? 5 : 10;
	result["generation"] = generation;
	result["pity"] = (int)record["fusion_pity"];
	return result;
}

mapping(string:mixed) query_pet_fusion_preview(object player,
	string first_id,string second_id)
{
	mapping result = pet_result(0,"合成预览暂不可用。");
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record)
		result = pet_fusion_preview_unlocked(record,first_id,second_id,
			VIPD->query_active_vip_level(player),player);
	destruct(key);
	return result;
}

private mapping(string:mixed) make_fusion_child_unlocked(mapping record,
	mapping first,mapping second,int generation,int forced_quality,
	int forced_polarity)
{
	array parents = ({first,second});
	int anchor_index = random(2);
	mapping anchor = parents[anchor_index];
	mapping other = parents[1-anchor_index];
	mapping child = make_pet_instance_unlocked(record,
		(string)anchor["species"],"yin-yang-fusion");
	int quality = forced_quality;
	int quality_roll;
	array(string) quality_names = ({"","灵契","玄契","天契","神契"});
	string polarity;
	if(!sizeof(child))
		return ([]);
	if(quality<1 || quality>4){
		quality_roll = random(100);
		quality = quality_roll<5 ? 4 :
			(quality_roll<20 ? 3 : (quality_roll<50 ? 2 : 1));
	}
	polarity = forced_polarity==0 ? "yin" :
		(forced_polarity==1 ? "yang" : (random(2) ? "yang" : "yin"));
	child["level"] = (int)first["level"]>(int)second["level"] ?
		(int)first["level"] : (int)second["level"];
	child["xp"] = (int)first["xp"]>(int)second["xp"] ?
		(int)first["xp"] : (int)second["xp"];
	if((int)child["level"]>=PET_LEVEL_MAX)
		child["xp"] = 0;
	child["star"] = (int)first["star"]>(int)second["star"] ?
		(int)first["star"] : (int)second["star"];
	child["bond"] = (int)first["bond"]>(int)second["bond"] ?
		(int)first["bond"] : (int)second["bond"];
	child["skill_set"] = random(2) ? (int)anchor["skill_set"] :
		(int)other["skill_set"];
	child["skills"] = ({
		(string)anchor["skills"][0],
		(string)other["skills"][1],
		random(2) ? (string)anchor["skills"][2] :
			(string)other["skills"][2],
	});
	array combined_variants = ({});
	multiset(string) variant_seen = (<>);
	foreach((array)first["variants"]+(array)second["variants"],
	   mixed raw_variant){
		string variant_name = (string)raw_variant;
		if(!variant_seen[variant_name]){
			variant_seen[variant_name] = 1;
			combined_variants += ({variant_name});
		}
	}
	child["variants"] = combined_variants;
	if(sizeof((array)child["variants"])>12)
		child["variants"] = child["variants"][0..11];
	mapping(string:int) percentages = ([]);
	foreach(({"life","attack","defense","spirit","speed"}),
	   string attribute)
		percentages[attribute] = 100+quality*2+random(quality*2+1);
	child["fusion"] = ([
		"name":quality_names[quality]+"·"+
			(string)shanhai_catalog[(string)first["species"]]["name"]+
			"×"+(string)shanhai_catalog[(string)second["species"]]["name"],
		"polarity":polarity,
		"quality":quality,
		"quality_name":quality_names[quality],
		"generation":generation,
		"growth_bonus":quality*3,
		"attribute_percent":percentages,
		"parents":({(string)first["species"],
			(string)second["species"]}),
		"traits":({query_pet_polarity_name(query_pet_polarity(first))+
			"脉承继",query_pet_polarity_name(query_pet_polarity(second))+
			"脉共鸣"}),
		"created_at":time(),
	]);
	return child;
}

private mapping(string:mixed) fuse_pets_locked(object player,
	string first_id,string second_id,int forced_success,
	int forced_quality,int forced_polarity)
{
	mapping result = pet_result(0,"本次阴阳合成没有生效。");
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	int vip_level;
	if(account_id=="")
		return result;
	if(player->query_in_combat && player->query_in_combat())
		return pet_result(0,"交战中不能进行灵宠合成。");
	vip_level = VIPD->query_active_vip_level(player);
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		mapping preview = pet_fusion_preview_unlocked(record,first_id,
			second_id,vip_level,player);
		if(!preview["ok"])
			result = preview;
		else if((int)record["materials"]["spirit_mark"]<
		   (int)preview["success_cost"])
			result["message"] = "灵印不足；开始合成需要准备10枚灵印。";
		else{
			int first_index = find_pet_index(record["pets"],first_id);
			int second_index = find_pet_index(record["pets"],second_id);
			mapping first = record["pets"][first_index];
			mapping second = record["pets"][second_index];
			int won = forced_success>=0 ? forced_success :
				random(100)<(int)preview["success_chance"];
			if(won){
				mapping child = make_fusion_child_unlocked(record,first,
					second,(int)preview["generation"],forced_quality,
					forced_polarity);
				if(!sizeof(child))
					result["message"] = "新灵契生成失败，材料和原宠均未变化。";
				else{
					array kept = ({});
					foreach((array)record["pets"],mapping pet)
						if((string)pet["id"]!=first_id &&
						   (string)pet["id"]!=second_id)
							kept += ({pet});
					record["pets"] = kept+({child});
					add_pet_material_unlocked(record,"spirit_mark",-10);
					record["fusion_pity"] = 0;
					record["revision"] = (int)record["revision"]+1;
					if(save_pet_record_unlocked(record)){
						result = pet_result(1,"阴阳相合成功，诞生"+
							(string)child["fusion"]["name"]+"！两只原灵宠的最高等级、星级与羁绊已经继承。");
						result["success"] = 1;
						result["pet"] = enrich_pet_view(child,player);
					}
				}
			}
			else{
				int failure_cost = (int)preview["failure_cost"];
				add_pet_material_unlocked(record,"spirit_mark",-failure_cost);
				record["fusion_pity"] = (int)record["fusion_pity"]+1;
				if((int)record["fusion_pity"]>5)
					record["fusion_pity"] = 5;
				record["revision"] = (int)record["revision"]+1;
				if(save_pet_record_unlocked(record)){
					result = pet_result(1,"阴阳合成未能稳定，两只原灵宠完整保留；消耗"+
						failure_cost+"枚灵印，失败积累提升到"+
						(int)record["fusion_pity"]+"/5。"+
						(vip_level>=3 ? "VIP3失败保护已返还一半灵印。" : ""));
					result["success"] = 0;
					result["pity"] = (int)record["fusion_pity"];
				}
			}
			if(result["ok"])
				ASYNC_IOD->append_log(ROOT+"/log/pet_fusion.log",
					time()+"|"+account_id+"|"+player->query_name()+"|"+
					(result["success"] ? "success" : "failure")+"|"+
					first_id+"|"+second_id+"\n");
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) fuse_pets(object player,string first_id,
	string second_id)
{
	return fuse_pets_locked(player,first_id,second_id,-1,0,-1);
}

mapping(string:mixed) test_fuse_pets(object player,string first_id,
	string second_id,int forced_success,int forced_quality,
	int forced_polarity)
{
	string account_id = resolve_pet_account(player);
	if(search(account_id,"testunit")==-1 ||
	   search(({0,1}),forced_success)==-1 || forced_quality<1 ||
	   forced_quality>4 || search(({0,1}),forced_polarity)==-1)
		return pet_result(0,"测试入口拒绝。");
	return fuse_pets_locked(player,first_id,second_id,forced_success,
		forced_quality,forced_polarity);
}

mapping(string:mixed) exchange_pet(object player,string species)
{
	mapping result = pet_result(0,"灵印兑换没有生效。");
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="" || !shanhai_catalog[species])
		return result;
	if(!(int)shanhai_catalog[species]["exchange"]){
		result["message"] = "这只异兽只能通过裂隙契约或特殊收藏取得。";
		return result;
	}
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		if(find_species_index(record["pets"],species)>=0)
			result["message"] = "图鉴已经收录这只异兽，不需要重复兑换。";
		else if((int)record["materials"]["spirit_mark"]<
			PET_EXCHANGE_MARKS)
			result["message"] = "灵印不足，稳定兑换需要30枚。";
		else{
			add_pet_material_unlocked(record,"spirit_mark",
				-PET_EXCHANGE_MARKS);
			result = acquire_pet_unlocked(record,species,"spirit_exchange");
			record["revision"] = (int)record["revision"]+1;
			if(!result["ok"] || !save_pet_record_unlocked(record))
				result = pet_result(0,"万灵谱保存失败，兑换没有生效。 ");
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) hatch_pet_fragments(object player,string species)
{
	mapping result = pet_result(0,"灵卵残片孵化没有生效。 ");
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="" || search(rift_boss_species,species)==-1)
		return pet_result(0,"灵卵残片只能稳定孵化裂隙异兽。 ");
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		if(find_species_index(record["pets"],species)>=0)
			result["message"] = "图鉴已经收录这只裂隙异兽，不会重复消耗残片。";
		else if((int)record["materials"]["egg_fragment"]<
			PET_FRAGMENT_HATCH_COST)
			result["message"] = "灵卵残片不足，稳定孵化需要60枚。";
		else{
			result = acquire_pet_unlocked(record,species,"fragment_hatch");
			if(result["ok"]){
				add_pet_material_unlocked(record,"egg_fragment",
					-PET_FRAGMENT_HATCH_COST);
				record["revision"] = (int)record["revision"]+1;
				if(!save_pet_record_unlocked(record))
					result = pet_result(0,"万灵谱保存失败，残片没有消耗。 ");
			}
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) unlock_pet_dust_variant(object player,string pet_id)
{
	mapping result = pet_result(0,"异色外观没有解锁。 ");
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		int index = find_pet_index(record["pets"],pet_id);
		if(index<0)
			result["message"] = "找不到这只灵宠。";
		else if(search((array)record["pets"][index]["variants"],
		   "星辉异色")!=-1)
			result["message"] = "这只灵宠已经解锁星辉异色。";
		else if((int)record["materials"]["cosmetic_dust"]<
			PET_COSMETIC_DUST_COST)
			result["message"] = "月华尘不足，保底解锁需要40份。";
		else{
			add_pet_material_unlocked(record,"cosmetic_dust",
				-PET_COSMETIC_DUST_COST);
			record["pets"][index]["variants"] += ({"星辉异色"});
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record))
				result = pet_result(1,"星辉异色已永久收录；它只改变外观，不增加属性。 ");
			else
				result["message"] = "万灵谱保存失败，月华尘没有消耗。";
		}
	}
	destruct(key);
	return result;
}

int reconcile_pet_player_login(object player)
{
	clear_pet_runtime(player);
	// 宠物附属文件损坏时仅关闭万灵入口，不能阻断人物旧存档登录。
	return refresh_pet_player_runtime(player);
}

mapping(string:mixed) test_grant_pet_species(object player,string species)
{
	mapping result = pet_result(0,"测试入口拒绝。 ");
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(search(account_id,"testunit")==-1 || !shanhai_catalog[species])
		return result;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		result = acquire_pet_unlocked(record,species,"testunit");
		record["starter_claimed"] = 1;
		record["revision"] = (int)record["revision"]+1;
		if(!save_pet_record_unlocked(record))
			result = pet_result(0,"测试保存失败。 ");
	}
	destruct(key);
	return result;
}

int test_add_pet_material(object player,string material,int amount)
{
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	int ok = 0;
	if(search(account_id,"testunit")==-1 || amount<0 || amount>10000 ||
	   !has_index(empty_pet_materials(),material))
		return 0;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		add_pet_material_unlocked(record,material,amount);
		record["revision"] = (int)record["revision"]+1;
		ok = save_pet_record_unlocked(record);
	}
	destruct(key);
	return ok;
}

#endif
