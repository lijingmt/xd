/** 图鉴、唯一宠物、培养、独立材料栏与每日寻迹。 */

#ifndef XIAND_PET_COLLECTION_PIKE
#define XIAND_PET_COLLECTION_PIKE

private mapping(string:mixed) pet_result(int ok,string message)
{
	return (["ok":ok,"message":message]);
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
		if(changed && (int)record["persisted"])
			save_pet_record_unlocked(record);
		result = copy_value(record);
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
				player["/tmp/wanling/pet_id"] = pet["id"];
				player["/tmp/wanling/species"] = species;
				player["/tmp/wanling/skill_set"] = 0;
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
	character_id = player->query_name();
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(!record)
		result["message"] = "万灵谱数据异常，本次没有修改。";
	else if(pet_id=="none"){
		m_delete(record["active"],character_id);
		record["revision"] = (int)record["revision"]+1;
		if(save_pet_record_unlocked(record)){
			player["/tmp/wanling/pet_id"] = 0;
			player["/tmp/wanling/species"] = 0;
			player["/tmp/wanling/skill_set"] = 0;
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
					player["/tmp/wanling/pet_id"] = pet_id;
					player["/tmp/wanling/species"] = pet["species"];
					player["/tmp/wanling/skill_set"] = pet["skill_set"];
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

mapping(string:mixed) train_pet_level(object player,string pet_id)
{
	mapping result = pet_result(0,"本次培养没有生效。");
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
		else{
			mapping pet = record["pets"][index];
			int level = (int)pet["level"];
			int cost = 2+level/5;
			if(level>=PET_LEVEL_MAX)
				result["message"] = "灵宠已经达到30级培养上限。";
			else if((int)record["materials"]["spirit_dew"]<cost)
				result["message"] = "灵露不足，需要"+cost+"滴。";
			else{
				add_pet_material_unlocked(record,"spirit_dew",-cost);
				pet["level"] = level+1;
				record["revision"] = (int)record["revision"]+1;
				if(save_pet_record_unlocked(record)){
					result = pet_result(1,(string)shanhai_catalog[
						(string)pet["species"]]["name"]+"成长到"+
						(int)pet["level"]+"级，消耗"+cost+"滴灵露。");
					result["level"] = pet["level"];
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
				if(save_pet_record_unlocked(record))
					result = pet_result(1,(string)shanhai_catalog[
						(string)pet["species"]]["name"]+"与你的羁绊升至"+
						(int)pet["bond"]+"阶。新的山海小传已经解锁。");
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
					player["/tmp/wanling/skill_set"] = next_set;
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
				add_pet_material_unlocked(record,"spirit_dew",6);
				add_pet_material_unlocked(record,"egg_fragment",1);
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
					tell_object(player,"【万灵寻迹完成】获得2枚灵印、6滴灵露、1枚灵卵残片和1枚同心叶。\n[查看今日修行:daily_cultivation]\n");
				else
					tell_object(player,"【万灵寻迹】线索进度 "+
						(progress-1)+"/3。\n");
			}
		}
	}
	destruct(key);
	return result;
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
	player["/tmp/wanling/pet_id"] = 0;
	player["/tmp/wanling/species"] = 0;
	player["/tmp/wanling/skill_set"] = 0;
	player["/tmp/wanling/assist_at"] = 0;
	if(account_id=="")
		return 1;
	character_id = player->query_name();
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		pet_id = (string)(record["active"][character_id] || "");
		int index = find_pet_index(record["pets"],pet_id);
		if(index>=0){
			player["/tmp/wanling/pet_id"] = pet_id;
			player["/tmp/wanling/species"] =
				record["pets"][index]["species"];
			player["/tmp/wanling/skill_set"] =
				record["pets"][index]["skill_set"];
		}
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
