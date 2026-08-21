/** 宠物独立三槽装备与受控的主人技能拓印。 */

#ifndef XIAND_PET_EQUIPMENT_PIKE
#define XIAND_PET_EQUIPMENT_PIKE

private mapping(string:mapping(string:string)) pet_gear_slots = ([
	"beast_armor":(["name":"兽铠","icon":"甲",
		"desc":"增强灵宠生命与防御"]),
	"spirit_charm":(["name":"灵饰","icon":"饰",
		"desc":"增强灵宠灵息、迅捷与少量战斗历练"]),
	"spirit_core":(["name":"灵核","icon":"核",
		"desc":"增强灵宠攻击，并承载主人技能拓印"]),
]);

mapping(string:mapping(string:string)) query_pet_gear_slots()
{
	return copy_value(pet_gear_slots);
}

int query_pet_gear_inventory_max()
{
	return PET_GEAR_INVENTORY_MAX;
}

private int find_pet_gear_index(array gear_inventory,string gear_id)
{
	for(int i=0;i<sizeof(gear_inventory);i++)
		if(mappingp(gear_inventory[i]) &&
		   (string)gear_inventory[i]["id"]==gear_id)
			return i;
	return -1;
}

private string query_pet_gear_equipped_by_unlocked(mapping record,
	string gear_id)
{
	foreach((array)record["pets"],mapping pet)
		foreach((mapping)pet["equipment"];string slot;mixed equipped_id)
			if((string)equipped_id==gear_id)
				return (string)pet["id"];
	return "";
}

private mapping(string:int) empty_pet_equipment_bonus()
{
	return (["life":0,"attack":0,"defense":0,"spirit":0,"speed":0]);
}

private void refresh_pet_equipment_bonus_unlocked(mapping record,
	mapping pet)
{
	mapping(string:int) bonus = empty_pet_equipment_bonus();
	foreach((mapping)pet["equipment"];string slot;mixed raw_gear_id){
		int index = find_pet_gear_index(record["gear_inventory"],
			(string)raw_gear_id);
		if(index<0)
			continue;
		mapping gear = record["gear_inventory"][index];
		foreach(indices(bonus),string attribute)
			bonus[attribute] = (int)bonus[attribute]+
				(int)gear["attributes"][attribute];
	}
	pet["equipment_bonus"] = bonus;
}

private int query_pet_equipment_xp_bonus_unlocked(mapping record,
	mapping pet)
{
	int total = 0;
	foreach((mapping)pet["equipment"];string slot;mixed raw_gear_id){
		int index = find_pet_gear_index(record["gear_inventory"],
			(string)raw_gear_id);
		if(index>=0)
			total += (int)record["gear_inventory"][index][
				"xp_bonus_percent"];
	}
	if(total>12)
		total = 12;
	return total;
}

private mapping(string:mixed) make_pet_gear_unlocked(mapping record,
	string slot,int quality,int level_requirement,string source)
{
	array(string) quality_names = ({"","凡品","良品","珍品","神品"});
	array(string) quality_prefixes = ({"","初契","凝光","山海","太初"});
	mapping(string:int) attributes = empty_pet_equipment_bonus();
	string gear_id;
	int value;
	if(!pet_gear_slots[slot] || quality<1 || quality>4)
		return ([]);
	if(level_requirement<1)
		level_requirement = 1;
	if(level_requirement>PET_LEVEL_MAX)
		level_requirement = PET_LEVEL_MAX;
	gear_id = new_pet_id_unlocked(record);
	if(gear_id=="")
		return ([]);
	value = quality+1+level_requirement/30;
	if(value>8)
		value = 8;
	if(slot=="beast_armor"){
		attributes["life"] = value;
		attributes["defense"] = value;
	}
	else if(slot=="spirit_charm"){
		attributes["spirit"] = value;
		attributes["speed"] = value>1 ? value-1 : 1;
	}
	else{
		attributes["attack"] = value;
		attributes["spirit"] = value>1 ? value-1 : 1;
	}
	return ([
		"id":gear_id,
		"slot":slot,
		"name":quality_prefixes[quality]+
			(string)pet_gear_slots[slot]["name"],
		"quality":quality,
		"quality_name":quality_names[quality],
		"level_requirement":level_requirement,
		"attributes":attributes,
		"xp_bonus_percent":slot=="spirit_charm" ? quality : 0,
		"source":source,
		"acquired_at":time(),
	]);
}

private array(mapping(string:mixed)) grant_starter_pet_gear_unlocked(
	mapping record,mapping pet)
{
	array(mapping(string:mixed)) granted = ({});
	if(sizeof((array)record["gear_inventory"])!=0 ||
	   sizeof((mapping)pet["equipment"])!=0)
		return granted;
	foreach(({"beast_armor","spirit_charm","spirit_core"}),string slot){
		mapping gear = make_pet_gear_unlocked(record,slot,1,1,"starter");
		if(!sizeof(gear)){
			foreach(granted,mapping rollback_gear){
				record["gear_inventory"] -= ({rollback_gear});
				m_delete(pet["equipment"],
					(string)rollback_gear["slot"]);
			}
			refresh_pet_equipment_bonus_unlocked(record,pet);
			return ({});
		}
		record["gear_inventory"] += ({gear});
		pet["equipment"][slot] = gear["id"];
		granted += ({gear});
	}
	refresh_pet_equipment_bonus_unlocked(record,pet);
	return granted;
}

mapping(string:mixed) claim_pet_starter_gear(object player,string pet_id)
{
	mapping result = (["ok":0,"message":"初契装备没有领取。"]);
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	if(player->query_in_combat && player->query_in_combat()){
		result["message"] = "交战中不能整理灵宠装备。";
		return result;
	}
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		int index = find_pet_index(record["pets"],pet_id);
		if(index<0)
			result["message"] = "找不到这只灵宠。";
		else if(sizeof((array)record["gear_inventory"]))
			result = (["ok":1,"message":"宠物装备栏已经建立。"]);
		else{
			array granted = grant_starter_pet_gear_unlocked(record,
				record["pets"][index]);
			if(sizeof(granted)==3){
				record["revision"] = (int)record["revision"]+1;
				if(save_pet_record_unlocked(record)){
					if(record["active"][player->query_name()]==pet_id)
						sync_pet_runtime_unlocked(player,
							record["pets"][index],0);
					result = (["ok":1,
						"message":"领取并自动穿戴了初契兽铠、灵饰和灵核。"]);
				}
			}
		}
	}
	destruct(key);
	return result;
}

private mapping(string:mixed) enrich_pet_equipment_view_unlocked(
	mapping record,mapping pet)
{
	mapping result = copy_value(pet);
	mapping details = ([]);
	foreach((mapping)pet["equipment"];string slot;mixed raw_gear_id){
		int index = find_pet_gear_index(record["gear_inventory"],
			(string)raw_gear_id);
		if(index>=0)
			details[slot] = copy_value(record["gear_inventory"][index]);
	}
	result["equipment_details"] = details;
	return result;
}

mapping(string:mixed) query_pet_equipment_state(object player,string pet_id)
{
	mapping result = (["ok":0,"message":"宠物装备栏暂不可用。"]);
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		int index = find_pet_index(record["pets"],pet_id);
		if(index>=0){
			array inventory = ({});
			foreach((array)record["gear_inventory"],mapping raw_gear){
				mapping gear = copy_value(raw_gear);
				gear["equipped_by"] =
					query_pet_gear_equipped_by_unlocked(record,
						(string)gear["id"]);
				inventory += ({gear});
			}
			result = ([
				"ok":1,
				"message":"",
				"pet":enrich_pet_view(
					enrich_pet_equipment_view_unlocked(record,
						record["pets"][index]),player),
				"gear_inventory":inventory,
				"slots":query_pet_gear_slots(),
				"inventory_max":PET_GEAR_INVENTORY_MAX,
			]);
		}
		else
			result["message"] = "找不到这只灵宠。";
	}
	destruct(key);
	return result;
}

mapping(string:mixed) equip_pet_gear(object player,string pet_id,
	string gear_id)
{
	mapping result = (["ok":0,"message":"灵宠装备没有变更。"]);
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	if(player->query_in_combat && player->query_in_combat()){
		result["message"] = "交战中不能更换灵宠装备。";
		return result;
	}
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		int pet_index = find_pet_index(record["pets"],pet_id);
		int gear_index = find_pet_gear_index(record["gear_inventory"],
			gear_id);
		if(pet_index<0 || gear_index<0)
			result["message"] = "灵宠或装备已经不存在，请刷新后重试。";
		else{
			mapping pet = record["pets"][pet_index];
			mapping gear = record["gear_inventory"][gear_index];
			string occupied_by =
				query_pet_gear_equipped_by_unlocked(record,gear_id);
			if(occupied_by!="" && occupied_by!=pet_id)
				result["message"] = "这件装备正由另一只灵宠穿戴。";
			else if(query_pet_effective_level(player,(int)pet["level"])<
			   (int)gear["level_requirement"])
				result["message"] = "灵宠等级不足，需要Lv."+
					(int)gear["level_requirement"]+"。";
			else{
				string slot = (string)gear["slot"];
				pet["equipment"][slot] = gear_id;
				refresh_pet_equipment_bonus_unlocked(record,pet);
				record["revision"] = (int)record["revision"]+1;
				if(save_pet_record_unlocked(record)){
					if(record["active"][player->query_name()]==pet_id)
						sync_pet_runtime_unlocked(player,pet,0);
					result = (["ok":1,"message":(string)gear["name"]+
						"已穿戴到"+(string)pet_gear_slots[slot]["name"]+"槽。"]);
				}
			}
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) unequip_pet_gear(object player,string pet_id,
	string slot)
{
	mapping result = (["ok":0,"message":"灵宠装备没有卸下。"]);
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="" || !pet_gear_slots[slot])
		return result;
	if(player->query_in_combat && player->query_in_combat()){
		result["message"] = "交战中不能卸下灵宠装备。";
		return result;
	}
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		int index = find_pet_index(record["pets"],pet_id);
		if(index>=0){
			mapping pet = record["pets"][index];
			if(!(string)(pet["equipment"][slot] || ""))
				result["message"] = "这个槽位本来就是空的。";
			else if(slot=="spirit_core" && pet["imprinted_skill"])
				result["message"] = "灵核承载着拓印技能，请先遗忘灵技再卸下。";
			else{
				m_delete(pet["equipment"],slot);
				refresh_pet_equipment_bonus_unlocked(record,pet);
				record["revision"] = (int)record["revision"]+1;
				if(save_pet_record_unlocked(record)){
					if(record["active"][player->query_name()]==pet_id)
						sync_pet_runtime_unlocked(player,pet,0);
					result = (["ok":1,"message":
						(string)pet_gear_slots[slot]["name"]+"已卸下。"]);
				}
			}
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) forge_pet_gear(object player,string slot)
{
	mapping result = (["ok":0,"message":"本次凝炼没有生成装备。"]);
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="" || !pet_gear_slots[slot])
		return result;
	if(player->query_in_combat && player->query_in_combat()){
		result["message"] = "交战中不能凝炼灵宠装备。";
		return result;
	}
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		string active_id = (string)(record["active"][player->query_name()] || "");
		int pet_index = find_pet_index(record["pets"],active_id);
		if(pet_index<0)
			result["message"] = "请先设置当前协战灵宠。";
		else if(sizeof((array)record["gear_inventory"])>=
		   PET_GEAR_INVENTORY_MAX)
			result["message"] = "宠物装备栏已满，请先分解闲置装备。";
		else if((int)record["materials"]["spirit_mark"]<5)
			result["message"] = "凝炼一件宠物装备需要5枚灵印。";
		else{
			int roll = random(100);
			int quality = roll<1 ? 4 : (roll<8 ? 3 : (roll<30 ? 2 : 1));
			int pet_level = query_pet_effective_level(player,
				(int)record["pets"][pet_index]["level"]);
			int requirement = ((pet_level-1)/10)*10+1;
			mapping gear = make_pet_gear_unlocked(record,slot,quality,
				requirement,"spirit-forge");
			if(sizeof(gear)){
				add_pet_material_unlocked(record,"spirit_mark",-5);
				record["gear_inventory"] += ({gear});
				record["revision"] = (int)record["revision"]+1;
				if(save_pet_record_unlocked(record))
					result = (["ok":1,"message":"凝炼获得"+
						(string)gear["quality_name"]+"·"+
						(string)gear["name"]+"。","gear":copy_value(gear)]);
			}
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) dismantle_pet_gear(object player,string gear_id)
{
	mapping result = (["ok":0,"message":"宠物装备没有分解。"]);
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	if(player->query_in_combat && player->query_in_combat()){
		result["message"] = "交战中不能分解灵宠装备。";
		return result;
	}
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		int index = find_pet_gear_index(record["gear_inventory"],gear_id);
		if(index<0)
			result["message"] = "找不到这件宠物装备。";
		else if(query_pet_gear_equipped_by_unlocked(record,gear_id)!="")
			result["message"] = "已穿戴装备不能分解，请先卸下。";
		else{
			mapping gear = record["gear_inventory"][index];
			int refund = (int)gear["quality"]*2;
			record["gear_inventory"] -= ({gear});
			add_pet_material_unlocked(record,"spirit_mark",refund);
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record))
				result = (["ok":1,"message":(string)gear["name"]+
					"已安全分解，返还"+refund+"枚灵印。"]);
		}
	}
	destruct(key);
	return result;
}

/** 一键分解全部未穿戴的低品质灵宠装备（quality<=max_quality）。 */
mapping(string:mixed) dismantle_pet_gear_batch(object player,
	int max_quality)
{
	mapping result = (["ok":0,"message":"没有可分解的宠物装备。"]);
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	array(mapping) removed = ({});
	int refund_total = 0;
	if(account_id=="")
		return (["ok":0,"message":"账号校验未通过，不能分解。"]);
	if(max_quality<1 || max_quality>3)
		return (["ok":0,"message":"一键分解只支持凡品、良品或珍品档。"]);
	if(player->query_in_combat && player->query_in_combat())
		return (["ok":0,"message":"交战中不能分解灵宠装备。"]);
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(!record){
		destruct(key);
		return (["ok":0,"message":"万灵谱档案读取失败，不能分解。"]);
	}
	if(record){
		foreach((array)record["gear_inventory"],mapping gear){
			// 穿戴态由宠物equipment引用表达（原始记录无equipped_by
			// 字段）；必须走统一助手，否则会移除仍被穿戴的装备并使
			// 存档校验拒绝保存。
			if((int)gear["quality"]>max_quality ||
			   query_pet_gear_equipped_by_unlocked(record,
					(string)gear["id"])!="")
				continue;
			removed += ({gear});
			refund_total += (int)gear["quality"]*2;
		}
		if(!sizeof(removed)){
			int total=sizeof((array)(record["gear_inventory"] || ({})));
			result=(["ok":0,"message":"没有可分解的宠物装备（低品质闲置0件/共"+
				total+"件）。"]);
		}
		if(sizeof(removed)){
			record["gear_inventory"] -= removed;
			add_pet_material_unlocked(record,"spirit_mark",refund_total);
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record))
				result = (["ok":1,"message":"已分解"+
					sizeof(removed)+"件低品质灵宠装备，共返还"+
					refund_total+"枚灵印。"]);
		}
	}
	destruct(key);
	return result;
}

/** TestUnit-only：按指定品质注入一件未穿戴灵宠装备。 */
mapping(string:mixed) test_forge_pet_gear_quality(object player,
	string slot,int quality)
{
	mapping result = (["ok":0,"message":"测试装备注入失败。"]);
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(search(account_id,"testunit")==-1 ||
	   !pet_gear_slots[slot] || quality<1 || quality>4)
		return result;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record && sizeof((array)record["gear_inventory"])<
	   PET_GEAR_INVENTORY_MAX){
		mapping gear = make_pet_gear_unlocked(record,slot,quality,1,
			"testunit");
		if(sizeof(gear)){
			record["gear_inventory"] += ({gear});
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record))
				result = (["ok":1,"message":"已注入测试装备。",
					"gear":copy_value(gear)]);
		}
	}
	destruct(key);
	return result;
}

private mapping(string:mixed) query_imprint_skill_candidate(object player,
	string skill_name)
{
	mapping result = ([]);
	object|zero skill = 0;
	mixed err = 0;
	if(!player || !skill_name || skill_name=="" || sizeof(skill_name)>64 ||
	   search(skill_name,"/")!=-1 || search(skill_name,"..")!=-1 ||
	   has_prefix(skill_name,"b_") || !player->skills ||
	   !arrayp(player->skills[skill_name]) ||
	   (int)player->skills[skill_name][0]<=0)
		return result;
	skill = MUD_SKILLSD[skill_name];
	if(!skill)
		err = catch { skill = (object)(ROOT+
			"/gamelib/single/skills/"+skill_name); };
	if(err || !skill || (string)(skill->s_type || "")!="zhudong")
		return result;
	string skill_type = (string)(skill->s_skill_type || "");
	string effect = "";
	if(skill_type=="heal")
		effect = "heal";
	else if(skill_type=="dot")
		effect = "dot";
	else if(search(({"phy","curse","huo_mofa_attack",
	   "bing_mofa_attack","feng_mofa_attack","du_mofa_attack"}),
	   skill_type)!=-1)
		effect = "damage";
	if(effect=="")
		return result;
	return ([
		"name":skill_name,
		"name_cn":(string)skill->query_name_cn(),
		"effect":effect,
		"level":(int)player->skills[skill_name][0],
	]);
}

array(mapping(string:mixed)) query_pet_imprint_skill_candidates(object player)
{
	array(mapping(string:mixed)) result = ({});
	if(!player || !player->skills)
		return result;
	foreach(sort(indices((mapping)player->skills)),string skill_name){
		mapping candidate = query_imprint_skill_candidate(player,skill_name);
		if(sizeof(candidate))
			result += ({candidate});
	}
	return result;
}

mapping(string:mixed) imprint_pet_skill(object player,string pet_id,
	string skill_name)
{
	mapping result = (["ok":0,"message":"灵技拓印没有生效。"]);
	string account_id = resolve_pet_account(player);
	mapping candidate = query_imprint_skill_candidate(player,skill_name);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="" || !sizeof(candidate)){
		result["message"] = "只能拓印当前人物真实学会的主动攻击或治疗技能。";
		return result;
	}
	if(player->query_in_combat && player->query_in_combat()){
		result["message"] = "交战中不能更换灵技拓印。";
		return result;
	}
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		int index = find_pet_index(record["pets"],pet_id);
		if(index<0)
			result["message"] = "找不到这只灵宠。";
		else{
			mapping pet = record["pets"][index];
			if(query_pet_effective_level(player,(int)pet["level"])<20)
				result["message"] = "灵宠达到20级后才能承受主人灵技。";
			else if(!(string)(pet["equipment"]["spirit_core"] || ""))
				result["message"] = "请先为灵宠穿戴灵核。";
			else if(mappingp(pet["imprinted_skill"]) &&
			   (string)pet["imprinted_skill"]["name"]==skill_name)
				result["message"] = "这项灵技已经拓印完成。";
			else if(pet["imprinted_skill"] &&
			   (int)record["materials"]["skill_rune"]<1)
				result["message"] = "首次拓印免费；替换已有灵技需要1枚灵纹符。";
			else{
				if(pet["imprinted_skill"])
					add_pet_material_unlocked(record,"skill_rune",-1);
				pet["imprinted_skill"] = ([
					"name":candidate["name"],
					"name_cn":candidate["name_cn"],
					"effect":candidate["effect"],
					"level":candidate["level"],
					"source_character":player->query_name(),
					"learned_at":time(),
				]);
				record["revision"] = (int)record["revision"]+1;
				if(save_pet_record_unlocked(record)){
					if(record["active"][player->query_name()]==pet_id)
						sync_pet_runtime_unlocked(player,pet,0);
					result = (["ok":1,"message":"灵宠已学会拓印·"+
						(string)candidate["name_cn"]+
						"；战斗中按宠物属性和安全上限释放。"]);
				}
			}
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) forget_pet_imprinted_skill(object player,
	string pet_id)
{
	mapping result = (["ok":0,"message":"灵宠没有遗忘任何灵技。"]);
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	if(player->query_in_combat && player->query_in_combat()){
		result["message"] = "交战中不能遗忘灵技。";
		return result;
	}
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		int index = find_pet_index(record["pets"],pet_id);
		if(index>=0 && record["pets"][index]["imprinted_skill"]){
			record["pets"][index]["imprinted_skill"] = 0;
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record)){
				if(record["active"][player->query_name()]==pet_id)
					sync_pet_runtime_unlocked(player,
						record["pets"][index],0);
				result = (["ok":1,"message":"灵宠已遗忘拓印技能，灵核可以更换。"]);
			}
		}
	}
	destruct(key);
	return result;
}

#endif
