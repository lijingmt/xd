/** 有上限的PVE协战与压缩成长PVP御灵。通用灵宠始终不生成NPC。 */

#ifndef XIAND_PET_ASSIST_PIKE
#define XIAND_PET_ASSIST_PIKE

int query_pet_pvp_charge_required(void|int skill_set)
{
	if(skill_set==1)
		return 4;
	if(skill_set==2)
		return 6;
	return 5;
}

private mapping(string:mixed) query_runtime_pet(object player)
{
	mapping result = ([]);
	string species;
	if(!player)
		return result;
	species = (string)(player["/tmp/wanling/species"] || "");
	if(!shanhai_catalog[species])
		return result;
	result["id"] = (string)(player["/tmp/wanling/pet_id"] || "");
	result["species"] = species;
	result["level"] = (int)player["/tmp/wanling/pet_level"];
	result["star"] = (int)player["/tmp/wanling/pet_star"];
	result["bond"] = (int)player["/tmp/wanling/pet_bond"];
	result["skill_set"] = (int)player["/tmp/wanling/skill_set"];
	result["imprinted_skill"] = mappingp(player[
		"/tmp/wanling/imprinted_skill"]) ?
		copy_value((mapping)player["/tmp/wanling/imprinted_skill"]) : 0;
	return result;
}

private string query_pet_active_skill_name(object player,mapping info)
{
	mapping imprint = mappingp(player["/tmp/wanling/imprinted_skill"]) ?
		player["/tmp/wanling/imprinted_skill"] : ([]);
	if((string)(imprint["name_cn"] || "")!="")
		return "拓印·"+(string)imprint["name_cn"];
	return (string)info["skill"];
}

private string query_pet_imprinted_effect(object player)
{
	mapping imprint = mappingp(player["/tmp/wanling/imprinted_skill"]) ?
		player["/tmp/wanling/imprinted_skill"] : ([]);
	string effect = (string)(imprint["effect"] || "");
	return search(({"damage","heal"}),effect)!=-1 ? effect : "";
}

mapping(string:mixed) query_pet_room_presence(object player)
{
	mapping result = (["active":0]);
	string species;
	mapping info;
	if(!player || !player->is || !player->is("player"))
		return result;
	species = (string)(player["/tmp/wanling/species"] || "");
	info = shanhai_catalog[species];
	if(!info)
		return result;
	return ([
		"active":1,
		"name":(string)(player["/tmp/wanling/pet_name"] ||
			info["name"]),
		"icon":(string)info["icon"],
		"role":(string)info["role"],
		"level":(int)player["/tmp/wanling/pet_level"],
		"star":(int)player["/tmp/wanling/pet_star"],
		"evolution_name":(string)(player[
			"/tmp/wanling/pet_evolution_name"] || "初生体"),
		"power":(int)player["/tmp/wanling/pet_power"],
		"skill":query_pet_active_skill_name(player,info),
		"native_skill":(string)info["skill"],
	]);
}

/**
 * 返回战斗小窗需要的轻量陪伴状态。这里只读取人物临时状态和内存图鉴，
 * 不读取账号文件；recent_event最多保留10秒，客户端按事件ID去重。
 */
mapping(string:mixed) query_pet_battle_presence(object player)
{
	mapping result = (["active":0]);
	string species;
	mapping info;
	mapping recent;
	mapping attributes;
	int skill_set;
	int cooldown;
	int assisted_at;
	int remaining;
	int event_at;
	string pvp_target;
	if(!player)
		return result;
	species = (string)(player["/tmp/wanling/species"] || "");
	info = shanhai_catalog[species];
	if(!info)
		return result;
	skill_set = (int)player["/tmp/wanling/skill_set"];
	cooldown = skill_set==1 ? 24 :
		(skill_set==2 ? 36 : PET_ASSIST_COOLDOWN);
	assisted_at = (int)player["/tmp/wanling/assist_at"];
	remaining = assisted_at+cooldown-time();
	if(remaining<0)
		remaining = 0;
	attributes = mappingp(player["/tmp/wanling/pet_attributes"]) ?
		copy_value((mapping)player["/tmp/wanling/pet_attributes"]) : ([]);
	pvp_target = (string)(player["/tmp/wanling/pvp_target"] || "");
	result = ([
		"active":1,
		"pet_id":(string)(player["/tmp/wanling/pet_id"] || ""),
		"species":species,
		"name":(string)(player["/tmp/wanling/pet_name"] ||
			info["name"]),
		"icon":(string)info["icon"],
		"family":(string)info["family"],
		"polarity":(string)(player["/tmp/wanling/pet_polarity"] || ""),
		"role":(string)info["role"],
		"skill":query_pet_active_skill_name(player,info),
		"native_skill":(string)info["skill"],
		"imprinted_skill":mappingp(player[
			"/tmp/wanling/imprinted_skill"]) ?
			copy_value((mapping)player[
				"/tmp/wanling/imprinted_skill"]) : 0,
		"skill_set":skill_set,
		"level":(int)player["/tmp/wanling/pet_level"],
		"star":(int)player["/tmp/wanling/pet_star"],
		"bond":(int)player["/tmp/wanling/pet_bond"],
		"evolution":(int)player["/tmp/wanling/pet_evolution"],
		"evolution_name":(string)(player[
			"/tmp/wanling/pet_evolution_name"] || "初生体"),
		"attributes":attributes,
		"power":(int)player["/tmp/wanling/pet_power"],
		"growth_percent":(int)player[
			"/tmp/wanling/pet_growth_percent"],
		"pvp_growth_percent":(int)player[
			"/tmp/wanling/pet_pvp_growth_percent"],
		"combat_mode":pvp_target!="" ? "pvp" : "pve",
		"cooldown":cooldown,
		"cooldown_remaining":remaining,
		"ready_at":assisted_at+cooldown,
		"pvp_charge":(int)player["/tmp/wanling/pvp_charge"],
		"pvp_charge_required":query_pet_pvp_charge_required(skill_set),
		"pvp_uses":(int)player["/tmp/wanling/pvp_uses"],
		"pvp_uses_max":PET_PVP_ASSIST_USES,
	]);
	if(pvp_target!=""){
		int required = (int)result["pvp_charge_required"];
		int charge = (int)result["pvp_charge"];
		if(charge>required)
			charge = required;
		result["pvp_charge"] = charge;
		result["cooldown"] = required;
		result["cooldown_remaining"] = required-charge;
		result["ready_at"] = 0;
	}
	if(species==PET_HIDDEN_LUAN_SPECIES){
		string revive_day_key = (string)(player[
			"/tmp/wanling/owner_revive_day_key"] || "");
		int revive_used = revive_day_key==current_pet_day_key() ?
			(int)player["/tmp/wanling/owner_revive_used"] : 0;
		if(revive_used<0)
			revive_used = 0;
		if(revive_used>1)
			revive_used = 1;
		result["owner_revive"] = ([
			"enabled":1,"skill":"回生羽","maximum":1,
			"used":revive_used,"remaining":1-revive_used,
			"life_percent":PET_OWNER_REVIVE_LIFE_PERCENT,
			"mofa_percent":PET_OWNER_REVIVE_MOFA_PERCENT,
		]);
	}
	if(mappingp(player["/tmp/wanling/recent_assist"])){
		recent = player["/tmp/wanling/recent_assist"];
		event_at = (int)recent["event_at"];
		if(event_at>0 && event_at<=time()+1 && time()-event_at<=10)
			result["recent_event"] = copy_value(recent);
	}
	return result;
}

mapping(string:mixed) query_pet_assist_profile(string species,
	int base_damage,int target_life_max,int player_life_max,
	int player_mofa_max,void|int skill_set,void|int growth_percent,
	void|string imprinted_effect)
{
	mapping info = shanhai_catalog[species];
	int amount_percent = 100;
	int cooldown = PET_ASSIST_COOLDOWN;
	mapping result = ([
		"type":"none","amount":0,"cooldown":cooldown,
	]);
	if(!info)
		return result;
	if(skill_set==1){
		amount_percent = 80;
		cooldown = 24;
	}
	else if(skill_set==2){
		amount_percent = 115;
		cooldown = 36;
	}
	if(growth_percent<100)
		growth_percent = 100;
	if(growth_percent>250)
		growth_percent = 250;
	result["cooldown"] = cooldown;
	string role = (string)info["role"];
	if(imprinted_effect=="damage" ||
	   (imprinted_effect!="heal" && (role=="强攻" || role=="迅捷"))){
		int amount = base_damage*2/100*amount_percent/100*
			growth_percent/100;
		int cap = target_life_max*2/1000*growth_percent/100;
		if(amount<1) amount = 1;
		if(cap<1) cap = 1;
		if(amount>cap) amount = cap;
		result["type"] = "damage";
		result["amount"] = amount;
	}
	else if(imprinted_effect!="heal" && role=="灵息"){
		int amount = player_mofa_max*2/100*amount_percent/100*
			growth_percent/100;
		if(amount<1) amount = 1;
		result["type"] = "mofa";
		result["amount"] = amount;
	}
	else{
		int amount = player_life_max*2/100*amount_percent/100*
			growth_percent/100;
		if(amount<1) amount = 1;
		result["type"] = "heal";
		result["amount"] = amount;
	}
	return result;
}

mapping(string:mixed) query_pet_pvp_assist_profile(string species,
	int base_damage,int target_life_max,int player_life_max,
	int player_mofa_max,void|int skill_set,void|int growth_percent,
	void|string imprinted_effect)
{
	mapping info = shanhai_catalog[species];
	int amount_percent = 100;
	mapping result = ([
		"type":"none","amount":0,
		"charge_required":query_pet_pvp_charge_required(skill_set),
		"max_uses":PET_PVP_ASSIST_USES,
	]);
	if(!info)
		return result;
	if(skill_set==1)
		amount_percent = 80;
	else if(skill_set==2)
		amount_percent = 115;
	if(growth_percent<100)
		growth_percent = 100;
	if(growth_percent>130)
		growth_percent = 130;
	string role = (string)info["role"];
	if(imprinted_effect=="damage" ||
	   (imprinted_effect!="heal" && (role=="强攻" || role=="迅捷"))){
		int amount = base_damage*8/100*amount_percent/100*
			growth_percent/100;
		int cap = target_life_max*4/1000*growth_percent/100;
		if(amount<1) amount = 1;
		if(cap<1) cap = 1;
		if(amount>cap) amount = cap;
		result["type"] = "damage";
		result["amount"] = amount;
	}
	else if(imprinted_effect!="heal" && role=="灵息"){
		int amount = player_mofa_max/100*amount_percent/100*
			growth_percent/100;
		if(amount<1) amount = 1;
		result["type"] = "mofa";
		result["amount"] = amount;
	}
	else{
		int amount = player_life_max/100*amount_percent/100*
			growth_percent/100;
		if(amount<1) amount = 1;
		result["type"] = "heal";
		result["amount"] = amount;
	}
	return result;
}

private int apply_pet_heal_reduction(object player,int amount)
{
	if(player->query_debuff("curse",0)=="life"){
		int heal_reduce = (int)player->query_debuff("curse",1);
		if(heal_reduce<0)
			heal_reduce = 0;
		if(heal_reduce>90)
			heal_reduce = 90;
		amount = amount*(100-heal_reduce)/100;
	}
	return amount;
}

private mapping(string:mixed) create_pet_assist_event(object player,
	object target,mapping info,string mode,string effect_type,int actual,
	int cooldown)
{
	string target_name = player->query_name();
	int event_at = time();
	int event_seq = (int)player["/tmp/wanling/assist_seq"]+1;
	if(target){
		target_name = target->query_name();
		if(functionp(target->query_name_cn) && target->query_name_cn()!="")
			target_name = target->query_name_cn();
	}
	player["/tmp/wanling/assist_seq"] = event_seq;
	return ([
		"id":sprintf("%s-%d-%d-%d",player->query_name(),event_at,event_seq,
			random(1000000)),
		"event_at":event_at,
		"pet_id":(string)(player["/tmp/wanling/pet_id"] || ""),
		"species":(string)(player["/tmp/wanling/species"] || ""),
		"name":(string)(player["/tmp/wanling/pet_name"] ||
			info["name"]),
		"icon":(string)info["icon"],
		"family":(string)info["family"],
		"role":(string)info["role"],
		"skill":query_pet_active_skill_name(player,info),
		"native_skill":(string)info["skill"],
		"mode":mode,
		"type":effect_type,
		"amount":actual,
		"target_name":target_name,
		"cooldown":cooldown,
		"ready_at":mode=="pve" ? event_at+cooldown : 0,
		"level":(int)player["/tmp/wanling/pet_level"],
		"star":(int)player["/tmp/wanling/pet_star"],
		"evolution_name":(string)(player[
			"/tmp/wanling/pet_evolution_name"] || "初生体"),
		"power":(int)player["/tmp/wanling/pet_power"],
	]);
}

mapping(string:mixed) perform_pet_pve_assist(object player,object target)
{
	mapping result = (["ok":0,"type":"none","amount":0]);
	string species;
	mapping info;
	mapping event;
	if(!player || !target || !player->is || !player->is("player") ||
	   !target->is || !target->is("npc") ||
	   player->get_cur_life()<=0 || target->get_cur_life()<=0 ||
	   environment(player)!=environment(target) ||
	   !LOGICALZONED->can_action("combat",player,target) ||
	   SUMMOND->query_combat_credit_owner(target)!=target)
		return result;
	species = (string)(player["/tmp/wanling/species"] || "");
	info = shanhai_catalog[species];
	if(!info)
		return result;
	result = query_pet_assist_profile(species,player->query_base_damage(),
		target->query_life_max(),player->query_life_max(),
		player->query_mofa_max(),
		(int)player["/tmp/wanling/skill_set"],
		(int)player["/tmp/wanling/pet_growth_percent"],
		query_pet_imprinted_effect(player));
	if((int)player["/tmp/wanling/assist_at"]+
	   (int)result["cooldown"]>time())
		return (["ok":0,"type":"none","amount":0]);
	string effect_type = (string)result["type"];
	int amount = (int)result["amount"];
	int actual = 0;
	if(effect_type=="damage" && target->get_cur_life()>1){
		actual = amount;
		if(actual>=target->get_cur_life())
			actual = target->get_cur_life()-1;
		if(actual>0){
			target->set_life(target->get_cur_life()-actual);
			target->flush_targets(player,actual);
			player->flush_targets(target,actual);
		}
	}
	else if(effect_type=="mofa"){
		int before = player->get_cur_mofa();
		int after = before+amount;
		if(after>player->query_mofa_max())
			after = player->query_mofa_max();
		if(after>before){
			player->set_mofa(after);
			actual = after-before;
		}
	}
	else if(effect_type=="heal"){
		int before = player->get_cur_life();
		amount = apply_pet_heal_reduction(player,amount);
		int after = before+amount;
		if(after>player->query_life_max())
			after = player->query_life_max();
		if(after>before){
			player->set_life(after);
			actual = after-before;
		}
	}
	// 满生命/法力也进入冷却，避免每个心跳反复判断和刷屏。
	player["/tmp/wanling/assist_at"] = time();
	result["ok"] = 1;
	result["amount"] = actual;
	event = create_pet_assist_event(player,
		effect_type=="damage" ? target : player,info,"pve",effect_type,
		actual,(int)result["cooldown"]);
	player["/tmp/wanling/recent_assist"] = copy_value(event);
	result["event"] = copy_value(event);
	if(actual>0){
		string unit = effect_type=="damage" ? "点协战伤害" :
			(effect_type=="mofa" ? "点法力" : "点生命");
		tell_object(player,"【万灵协战】"+
		(string)(player["/tmp/wanling/pet_name"] || info["name"])+"施展"+
			query_pet_active_skill_name(player,info)+"，带来"+actual+unit+"。\n");
	}
	else
		tell_object(player,"【万灵协战】"+
		(string)(player["/tmp/wanling/pet_name"] || info["name"])+"施展"+
			query_pet_active_skill_name(player,info)+"，守护在你身旁。\n");
	return result;
}

mapping(string:mixed) perform_pet_pvp_assist(object player,object target)
{
	mapping result = (["ok":0,"type":"none","amount":0]);
	object target_owner;
	string target_owner_id;
	string species;
	mapping info;
	mapping event;
	int required;
	int charge;
	int uses;
	if(!player || !target || !player->is || !player->is("player") ||
	   !target->is || player->get_cur_life()<=0 ||
	   target->get_cur_life()<=0 ||
	   environment(player)!=environment(target) ||
	   !LOGICALZONED->can_action("combat",player,target))
		return result;
	target_owner = target->is("player") ? target :
		SUMMOND->query_combat_credit_owner(target);
	if(!target_owner ||
	   (target_owner==target && !target->is("player")) ||
	   !target_owner->is || !target_owner->is("player") ||
	   target_owner==player ||
	   environment(target_owner)!=environment(player) ||
	   target_owner->get_cur_life()<=0)
		return result;
	if(!player->query_in_combat || !player->query_in_combat() ||
	   !target_owner->query_in_combat || !target_owner->query_in_combat())
		return result;
	if(player->query_enemy){
		object active_target = player->query_enemy();
		object active_owner = active_target && active_target->is("player") ?
			active_target : SUMMOND->query_combat_credit_owner(active_target);
		if(active_owner!=target_owner)
			return result;
	}
	species = (string)(player["/tmp/wanling/species"] || "");
	info = shanhai_catalog[species];
	if(!info)
		return result;
	target_owner_id = target_owner->query_name();
	if((string)(player["/tmp/wanling/pvp_target"] || "")!=
	   target_owner_id){
		player["/tmp/wanling/pvp_target"] = target_owner_id;
		player["/tmp/wanling/pvp_charge"] = 0;
	}
	uses = (int)player["/tmp/wanling/pvp_uses"];
	if(uses>=PET_PVP_ASSIST_USES)
		return result;
	required = query_pet_pvp_charge_required(
		(int)player["/tmp/wanling/skill_set"]);
	charge = (int)player["/tmp/wanling/pvp_charge"]+1;
	if(charge<required){
		player["/tmp/wanling/pvp_charge"] = charge;
		result["charging"] = 1;
		result["charge"] = charge;
		result["charge_required"] = required;
		return result;
	}
	player["/tmp/wanling/pvp_charge"] = 0;
	player["/tmp/wanling/pvp_uses"] = uses+1;
	result = query_pet_pvp_assist_profile(species,
		player->query_base_damage(),target->query_life_max(),
		player->query_life_max(),player->query_mofa_max(),
		(int)player["/tmp/wanling/skill_set"],
		(int)player["/tmp/wanling/pet_pvp_growth_percent"],
		query_pet_imprinted_effect(player));
	string effect_type = (string)result["type"];
	int amount = (int)result["amount"];
	int actual = 0;
	if(effect_type=="damage" && target->get_cur_life()>1){
		actual = amount;
		if(actual>=target->get_cur_life())
			actual = target->get_cur_life()-1;
		if(actual>0){
			target->set_life(target->get_cur_life()-actual);
			target->flush_targets(player,actual);
			player->flush_targets(target,actual);
		}
	}
	else if(effect_type=="mofa"){
		int before = player->get_cur_mofa();
		int after = before+amount;
		if(after>player->query_mofa_max())
			after = player->query_mofa_max();
		if(after>before){
			player->set_mofa(after);
			actual = after-before;
		}
	}
	else if(effect_type=="heal"){
		int before = player->get_cur_life();
		amount = apply_pet_heal_reduction(player,amount);
		int after = before+amount;
		if(after>player->query_life_max())
			after = player->query_life_max();
		if(after>before){
			player->set_life(after);
			actual = after-before;
		}
	}
	result["ok"] = 1;
	result["amount"] = actual;
	result["uses"] = uses+1;
	event = create_pet_assist_event(player,
		effect_type=="damage" ? target : player,info,"pvp",effect_type,
		actual,required);
	event["pvp_uses"] = uses+1;
	event["pvp_uses_max"] = PET_PVP_ASSIST_USES;
	player["/tmp/wanling/recent_assist"] = copy_value(event);
	result["event"] = copy_value(event);
	if(actual>0){
		string unit = effect_type=="damage" ? "点御灵伤害" :
			(effect_type=="mofa" ? "点法力" : "点生命");
		tell_object(player,"【御灵交锋】"+
		(string)(player["/tmp/wanling/pet_name"] || info["name"])+"施展"+
			query_pet_active_skill_name(player,info)+"，带来"+actual+unit+"（本场"+
			(uses+1)+"/"+PET_PVP_ASSIST_USES+"）。\n");
		tell_object(target_owner,"【御灵交锋】"+player->query_name_cn()+
			"的"+(string)(player["/tmp/wanling/pet_name"] ||
				info["name"])+"施展"+query_pet_active_skill_name(player,info)+
			"。\n");
	}
	else
		tell_object(player,"【御灵交锋】"+
		(string)(player["/tmp/wanling/pet_name"] || info["name"])+"施展"+
			query_pet_active_skill_name(player,info)+"，与你并肩守住战局（本场"+
			(uses+1)+"/"+PET_PVP_ASSIST_USES+"）。\n");
	return result;
}

mapping(string:mixed) perform_pet_combat_assist(object player,object target)
{
	object owner;
	mapping result;
	if(!player || !target || !target->is)
		return (["ok":0,"type":"none","amount":0]);
	if(target->is("player"))
		result = perform_pet_pvp_assist(player,target);
	else{
		owner = SUMMOND->query_combat_credit_owner(target);
		if(owner && owner!=target && owner->is && owner->is("player"))
			result = perform_pet_pvp_assist(player,target);
		else
			result = perform_pet_pve_assist(player,target);
	}
	if(result["ok"])
		DAILYGOALD->record_pet_assist(player);
	return result;
}

/**
 * 隐藏鸾鸟的回生羽只在主人真正进入死亡结算时判定。灵医的职业
 * 复苏在user.pike中先判定；只有职业复苏未触发时才会消耗这一次
 * 账号级每日保命。成功返回1时，调用者必须立即中止后续死亡流程。
 */
int try_pet_owner_revive(object player,object killer)
{
	object env;
	string account_id;
	string character_id;
	mapping(string:mixed)|zero record;
	object key;
	int consumed = 0;
	int life_restore;
	int mofa_restore;
	mapping info;
	mapping event;
	if(!player || !player->is || !player->is("player") ||
	   (string)(player["/tmp/wanling/species"] || "")!=
		PET_HIDDEN_LUAN_SPECIES || !killer || !objectp(killer) ||
	   player->get_cur_life()>0 || player->is("ghost") ||
	   player->sucide || player["/tmp/wanling/owner_revive_running"])
		return 0;
	env = environment(player);
	if(!env || environment(killer)!=env ||
	   !LOGICALZONED->can_action("combat",player,killer))
		return 0;
	if(functionp(env->query_room_type) && env->query_room_type()=="city")
		return 0;
	// 双方都没有击杀标记时只是友好切磋，不消耗稀有次数。
	if(functionp(killer->is) && killer->is("player") &&
	   player->kill_flag==0 && killer->kill_flag==0)
		return 0;
	account_id = resolve_pet_account(player);
	character_id = player->query_name();
	if(account_id=="")
		return 0;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		refresh_pet_periods_unlocked(record);
		string active_id = (string)(record["active"][character_id] || "");
		int pet_index = find_pet_index(record["pets"],active_id);
		if(pet_index>=0 &&
		   (string)record["pets"][pet_index]["species"]==
			PET_HIDDEN_LUAN_SPECIES &&
		   !(int)record["daily"]["owner_revive"]){
			record["daily"]["owner_revive"] = 1;
			record["revision"] = (int)record["revision"]+1;
			consumed = save_pet_record_unlocked(record);
		}
	}
	destruct(key);
	if(!consumed)
		return 0;
	player["/tmp/wanling/owner_revive_running"] = 1;
	player["/tmp/wanling/owner_revive_day_key"] = current_pet_day_key();
	player["/tmp/wanling/owner_revive_used"] = 1;
	player->_clean_fight();
	if(killer && objectp(killer) && functionp(killer->clean_targets))
		killer->clean_targets(player);
	life_restore = player->query_life_max()*
		PET_OWNER_REVIVE_LIFE_PERCENT/100;
	mofa_restore = player->query_mofa_max()*
		PET_OWNER_REVIVE_MOFA_PERCENT/100;
	if(life_restore<1)
		life_restore = 1;
	if(mofa_restore<1)
		mofa_restore = 1;
	player->set_life(life_restore);
	player->set_mofa(mofa_restore);
	player->m_delete_foruser("/tmp/wanling/owner_revive_running");
	info = shanhai_catalog[PET_HIDDEN_LUAN_SPECIES];
	event = create_pet_assist_event(player,player,info,
		functionp(killer->is) && killer->is("player") ? "pvp" : "pve",
		"revive",life_restore,0);
	event["skill"] = (string)info["skill"];
	event["mofa_amount"] = mofa_restore;
	event["daily_remaining"] = 0;
	player["/tmp/wanling/recent_assist"] = copy_value(event);
	catch {
		foreach(all_inventory(env),object observer)
			if(observer && functionp(observer->is) && observer->is("player"))
				tell_object(observer,"【回生羽】"+
					player->query_name_cn()+
					"的鸾鸟燃起五采灵羽，在死亡前唤回主人（今日已使用）。\n");
	};
	ASYNC_IOD->append_log(ROOT+"/log/pet_owner_revive.log",
		time()+"|"+account_id+"|"+character_id+"|killer="+
		killer->query_name()+"|life="+life_restore+"|mofa="+
		mofa_restore+"\n");
	return 1;
}

/** 快速决胜读取的剩余PVP宠物能力，只取人物临时快照，不访问磁盘。 */
mapping(string:mixed) query_pet_pk_fast_profile(object player,object target)
{
	mapping result = (["active":0]);
	mapping profile;
	string species;
	int uses;
	int charge;
	int required;
	if(!player || !target || !target->is || !target->is("player") ||
	   environment(player)!=environment(target))
		return result;
	species = (string)(player["/tmp/wanling/species"] || "");
	if(!shanhai_catalog[species])
		return result;
	uses = (int)player["/tmp/wanling/pvp_uses"];
	if(uses<0)
		uses = 0;
	if(uses>PET_PVP_ASSIST_USES)
		uses = PET_PVP_ASSIST_USES;
	profile = query_pet_pvp_assist_profile(species,
		player->query_base_damage(),target->query_life_max(),
		player->query_life_max(),player->query_mofa_max(),
		(int)player["/tmp/wanling/skill_set"],
		(int)player["/tmp/wanling/pet_pvp_growth_percent"],
		query_pet_imprinted_effect(player));
	profile["active"] = 1;
	profile["remaining_uses"] = PET_PVP_ASSIST_USES-uses;
	required = (int)profile["charge_required"];
	charge = (int)player["/tmp/wanling/pvp_charge"];
	// 快速决胜切到新对手时必须与真实心跳一致，从0重新充能。
	if((string)(player["/tmp/wanling/pvp_target"] || "")!=
	   target->query_name())
		charge = 0;
	if(charge<0)
		charge = 0;
	if(charge>=required)
		charge = required-1;
	profile["charge"] = charge;
	if(profile["type"]=="heal")
		profile["amount"] = apply_pet_heal_reduction(player,
			(int)profile["amount"]);
	return profile;
}

#endif
