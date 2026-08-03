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
	player["/tmp/wanling/assist_at"] = 0;
	player["/tmp/wanling/assist_seq"] = 0;
	player["/tmp/wanling/recent_assist"] = 0;
	player["/tmp/wanling/pvp_target"] = 0;
	player["/tmp/wanling/pvp_charge"] = 0;
	player["/tmp/wanling/pvp_uses"] = 0;
}

private void sync_pet_runtime_unlocked(object player,mapping pet,
	void|int reset_combat)
{
	mapping attributes;
	int star;
	if(!player || !mappingp(pet))
		return;
	star = (int)pet["star"];
	if(star<1)
		star = 1;
	attributes = query_pet_attributes(pet);
	player["/tmp/wanling/pet_id"] = pet["id"];
	player["/tmp/wanling/species"] = pet["species"];
	player["/tmp/wanling/skill_set"] = pet["skill_set"];
	player["/tmp/wanling/pet_level"] = pet["level"];
	player["/tmp/wanling/pet_star"] = star;
	player["/tmp/wanling/pet_bond"] = pet["bond"];
	player["/tmp/wanling/pet_evolution"] =
		query_pet_evolution_stage(star);
	player["/tmp/wanling/pet_evolution_name"] =
		query_pet_evolution_name(star);
	player["/tmp/wanling/pet_attributes"] = copy_value(attributes);
	player["/tmp/wanling/pet_power"] = (int)attributes["power"];
	player["/tmp/wanling/pet_growth_percent"] =
		query_pet_growth_percent(pet,0);
	player["/tmp/wanling/pet_pvp_growth_percent"] =
		query_pet_growth_percent(pet,1);
	player["/tmp/wanling/pet_name"] = mappingp(pet["fusion"]) &&
		(string)pet["fusion"]["name"]!="" ?
		(string)pet["fusion"]["name"] :
		(string)shanhai_catalog[(string)pet["species"]]["name"];
	player["/tmp/wanling/pet_polarity"] = query_pet_polarity(pet);
	if(reset_combat){
		player["/tmp/wanling/assist_at"] = 0;
		player["/tmp/wanling/recent_assist"] = 0;
		player["/tmp/wanling/pvp_target"] = 0;
		player["/tmp/wanling/pvp_charge"] = 0;
		player["/tmp/wanling/pvp_uses"] = 0;
	}
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
		foreach((array)result["pets"],mapping pet)
			enriched_pets += ({enrich_pet_view(pet)});
		result["pets"] = enriched_pets;
		result["ok"] = 1;
		result["message"] = "";
		result["character_id"] = player->query_name();
		result["starter_level"] = PET_STARTER_LEVEL;
		result["catalog_total"] = sizeof(shanhai_catalog);
		result["collection_count"] = sizeof((array)record["pets"]);
		result["weekly_boss"] = query_weekly_boss_species();
	}
	destruct(key);
	return result;
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
			mapping pet = result["pet"];
			record["starter_claimed"] = 1;
			record["active"][character_id] = pet["id"];
			add_pet_material_unlocked(record,"spirit_dew",12);
			add_pet_material_unlocked(record,"bond_token",2);
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record)){
				sync_pet_runtime_unlocked(player,pet,1);
				result["message"] +=
					"它已设为当前协战伙伴，并获赠12滴灵露与2枚同心叶。";
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
			int level = (int)pet["level"];
			int start_level = level;
			int total_cost = 0;
			int trained = 0;
			int available = (int)record["materials"]["spirit_dew"];
			int next_cost = 2+level/5;
			if(level>=PET_LEVEL_MAX)
				result["message"] = "灵宠已经达到"+PET_LEVEL_MAX+
					"级培养上限。";
			else{
				while(trained<requested && level<PET_LEVEL_MAX){
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
								result["message"] += level>=PET_LEVEL_MAX ?
									"已达到培养上限。" :
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
			result["message"] = "需要1枚灵纹符；周目标可稳定取得。";
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

private mapping(string:mixed) record_pet_pve_fragment_unlocked(
	object player,object npc,int forced_roll)
{
	mapping result = (["ok":0,"dropped":0,"chance":0,
		"source":"普通怪物","daily_cap":PET_PVE_FRAGMENT_DAILY_CAP]);
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

/** 普通同级怪、副本怪和BOSS都可独立产出残片，并按账号设置每日上限。 */
mapping(string:mixed) record_pet_pve_kill(object player,object npc)
{
	return record_pet_pve_fragment_unlocked(player,npc,-1);
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
	string first_id,string second_id,int vip_level)
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
	result["first"] = enrich_pet_view(first);
	result["second"] = enrich_pet_view(second);
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
			VIPD->query_active_vip_level(player));
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
			second_id,vip_level);
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
						result["pet"] = enrich_pet_view(child);
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
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	string character_id;
	string pet_id;
	object key;
	clear_pet_runtime(player);
	if(account_id=="")
		return 1;
	character_id = player->query_name();
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		pet_id = (string)(record["active"][character_id] || "");
		int index = find_pet_index(record["pets"],pet_id);
		if(index>=0)
			sync_pet_runtime_unlocked(player,record["pets"][index],1);
	}
	destruct(key);
	// 宠物附属文件损坏时仅关闭万灵入口，不能阻断人物旧存档登录。
	return 1;
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
