/** 有上限的PVE协战与压缩成长PVP御灵。通用灵宠始终不生成NPC。 */

#ifndef XIAND_PET_ASSIST_PIKE
#define XIAND_PET_ASSIST_PIKE

// 拓印持续伤害只继承人物真实每跳公式的一部分：普通PVE强调养成反馈，
// Boss与PVP进一步收敛，避免高生命百分比技能绕过协战平衡。
int query_pet_dot_inheritance_percent(string mode,int is_boss)
{
	if(mode=="pvp")
		return 15;
	if(is_boss)
		return 20;
	return 35;
}

int query_pet_pvp_charge_required(void|int skill_set)
{
	if(skill_set==1)
		return 4;
	if(skill_set==2)
		return 6;
	return 5;
}

/** 只读说明与真实结算常量保持一致，不改变任何宠物数值。 */
mapping(string:mixed) query_pet_rune_rhythm_profile(int skill_set)
{
	if(skill_set==1)
		return (["name":"轻灵","effect_percent":80,
			"pve_cooldown":24,"pvp_charge":4]);
	if(skill_set==2)
		return (["name":"厚积","effect_percent":115,
			"pve_cooldown":36,"pvp_charge":6]);
	return (["name":"均衡","effect_percent":100,
		"pve_cooldown":30,"pvp_charge":5]);
}

string query_pet_rune_rhythm_description(int skill_set,
	void|string effect_label)
{
	mapping profile = query_pet_rune_rhythm_profile(skill_set);
	string label = effect_label && effect_label!="" ? effect_label : "当前灵技";
	return (string)profile["name"]+"共鸣：三枚灵纹整套触发，"+
		label+"为"+(int)profile["effect_percent"]+"%效果；PVE每"+
		(int)profile["pve_cooldown"]+"秒一次，PVP蓄能"+
		(int)profile["pvp_charge"]+"回合且每场最多2次。";
}

private array(string) query_pet_runtime_runes(object player,mapping info)
{
	array(string) result = ({});
	mixed raw;
	int skill_set;
	if(!player || !mappingp(info))
		return result;
	raw = player["/tmp/wanling/pet_skills"];
	if(arrayp(raw) && sizeof((array)raw)==3){
		foreach((array)raw,mixed rune)
			if(stringp(rune) && (string)rune!="")
				result += ({(string)rune});
		if(sizeof(result)==3)
			return result;
	}
	result = ({});
	skill_set = (int)player["/tmp/wanling/skill_set"];
	if(skill_set<0 || skill_set>2)
		skill_set = 0;
	if(arrayp(info["skill_sets"]) &&
	   sizeof((array)info["skill_sets"])>skill_set &&
	   arrayp(info["skill_sets"][skill_set]))
		foreach((array)info["skill_sets"][skill_set],mixed rune)
			if(stringp(rune) && (string)rune!="")
				result += ({(string)rune});
	return result;
}

private int query_pet_rune_combo_active(object player,mapping info)
{
	return mappingp(player["/tmp/wanling/pet_fusion"]) &&
		sizeof(query_pet_runtime_runes(player,info))==3;
}

private string query_pet_rune_mode_name(object player)
{
	return (string)query_pet_rune_rhythm_profile(
		(int)player["/tmp/wanling/skill_set"])["name"];
}

private string query_pet_runtime_effect_label(object player,mapping info)
{
	string imprinted_effect = query_pet_imprinted_effect(player);
	string role = (string)info["role"];
	if(imprinted_effect=="damage")
		return "拓印攻击";
	if(imprinted_effect=="dot")
		return "拓印持续伤害";
	if(imprinted_effect=="heal")
		return "拓印治疗";
	if(role=="强攻" || role=="迅捷")
		return "协战伤害";
	if(role=="灵息")
		return "法力回复";
	return "生命回复";
}

private string query_pet_runtime_rune_description(object player,mapping info)
{
	return query_pet_rune_rhythm_description(
		(int)player["/tmp/wanling/skill_set"],
		query_pet_runtime_effect_label(player,info));
}

private string query_pet_active_skill_name(object player,mapping info)
{
	mapping imprint = mappingp(player["/tmp/wanling/imprinted_skill"]) ?
		player["/tmp/wanling/imprinted_skill"] : ([]);
	array(string) runes;
	runes = query_pet_runtime_runes(player,info);
	// 融合宠的三枚灵纹来自不同父系，不能再用锚定种族的原生技能名
	// 覆盖。三纹作为一个共鸣组合触发，结算仍沿用既有角色与节奏，
	// 只修复战斗读取和可见性，不额外叠加数值。
	if((string)(imprint["name_cn"] || "")!=""){
		string name = "拓印·"+(string)imprint["name_cn"];
		if(query_pet_rune_combo_active(player,info))
			name += "·三灵纹共鸣（"+runes*"·"+"）";
		return name;
	}
	if(query_pet_rune_combo_active(player,info))
		return "三灵纹共鸣（"+runes*"·"+"）";
	return (string)info["skill"];
}

private object|zero query_pet_imprinted_skill_object(object player)
{
	mapping imprint = mappingp(player["/tmp/wanling/imprinted_skill"]) ?
		player["/tmp/wanling/imprinted_skill"] : ([]);
	string name = (string)(imprint["name"] || "");
	object|zero skill = 0;
	mixed err = 0;
	if(name=="" || sizeof(name)>64 || search(name,"/")!=-1 ||
	   search(name,"..")!=-1)
		return 0;
	skill = MUD_SKILLSD[name];
	if(!skill)
		err = catch { skill = (object)(ROOT+
			"/gamelib/single/skills/"+name); };
	if(err)
		return 0;
	return skill;
}

private string query_pet_imprinted_effect(object player)
{
	mapping imprint = mappingp(player["/tmp/wanling/imprinted_skill"]) ?
		player["/tmp/wanling/imprinted_skill"] : ([]);
	string effect = (string)(imprint["effect"] || "");
	object|zero skill = query_pet_imprinted_skill_object(player);
	if(skill && (string)(skill->s_skill_type || "")=="dot")
		return "dot";
	return search(({"damage","heal","dot"}),effect)!=-1 ? effect : "";
}

private int query_pet_imprinted_dot_duration(object player)
{
	mapping imprint = mappingp(player["/tmp/wanling/imprinted_skill"]) ?
		player["/tmp/wanling/imprinted_skill"] : ([]);
	object|zero skill = query_pet_imprinted_skill_object(player);
	int skill_level = (int)imprint["level"];
	int duration = 4;
	if(skill_level<1)
		skill_level = 1;
	if(skill && functionp(skill->query_s_lasttime))
		duration = (int)skill->query_s_lasttime(skill_level);
	if(duration<2)
		duration = 2;
	if(duration>12)
		duration = 12;
	return duration;
}

mapping(string:mixed) query_pet_imprinted_dot_profile(object player,
	object target,int safe_total,string mode)
{
	mapping result = (["tick_damage":0,"duration":0,"total_amount":0,
		"source_tick":0,"inherit_percent":0,"rhythm_percent":100,
		"fallback_tick":0]);
	mapping imprint;
	object|zero skill;
	int skill_level;
	int duration;
	int fallback_tick;
	int source_tick;
	int inherit_percent;
	int rhythm_percent;
	int tick_damage;
	int is_boss;
	if(!player || !target)
		return result;
	imprint = mappingp(player["/tmp/wanling/imprinted_skill"]) ?
		player["/tmp/wanling/imprinted_skill"] : ([]);
	skill = query_pet_imprinted_skill_object(player);
	if(!skill || (string)(skill->s_skill_type || "")!="dot" ||
	   !functionp(player->query_active_dot_damage))
		return result;
	skill_level = (int)imprint["level"];
	if(skill_level<1)
		skill_level = 1;
	duration = query_pet_imprinted_dot_duration(player);
	fallback_tick = safe_total/duration;
	if(fallback_tick<1)
		fallback_tick = 1;
	is_boss = target->is("npc") && target->_boss;
	inherit_percent = query_pet_dot_inheritance_percent(mode,is_boss);
	rhythm_percent = (int)query_pet_rune_rhythm_profile(
		(int)player["/tmp/wanling/skill_set"])["effect_percent"];
	source_tick = (int)player->query_active_dot_damage(skill,skill_level,target);
	tick_damage = source_tick*inherit_percent*rhythm_percent/10000;
	// 低固定伤害技能至少保留旧协战安全预算，不因统一继承公式被削弱。
	if(tick_damage<fallback_tick)
		tick_damage = fallback_tick;
	if(tick_damage<1)
		tick_damage = 1;
	result["tick_damage"] = tick_damage;
	result["duration"] = duration;
	result["total_amount"] = tick_damage*duration;
	result["source_tick"] = source_tick;
	result["inherit_percent"] = inherit_percent;
	result["rhythm_percent"] = rhythm_percent;
	result["fallback_tick"] = fallback_tick;
	return result;
}

private mapping(string:mixed) apply_pet_imprinted_dot(object player,
	object target,int safe_total,string mode)
{
	mapping result = (["applied":0,"tick_damage":0,"duration":0,
		"total_amount":0,"source_tick":0,"inherit_percent":0,
		"rhythm_percent":100,"fallback_tick":0]);
	mapping imprint;
	string skill_name;
	if(!player || !target || safe_total<1 ||
	   !functionp(player->apply_nonstacking_dot))
		return result;
	imprint = mappingp(player["/tmp/wanling/imprinted_skill"]) ?
		player["/tmp/wanling/imprinted_skill"] : ([]);
	skill_name = (string)(imprint["name"] || "");
	if(skill_name=="")
		return result;
	result = query_pet_imprinted_dot_profile(player,target,safe_total,mode);
	if((int)result["tick_damage"]<1 || (int)result["duration"]<1)
		return result;
	if(!player->apply_nonstacking_dot(target,skill_name,
	   (int)result["tick_damage"],(int)result["duration"],1))
		return result;
	result["applied"] = 1;
	return result;
}

private string query_pet_waiting_resource(object player,mapping info)
{
	string imprinted_effect = query_pet_imprinted_effect(player);
	string role = (string)info["role"];
	if(imprinted_effect=="damage" || imprinted_effect=="dot" ||
	   (imprinted_effect!="heal" && (role=="强攻" || role=="迅捷")))
		return "";
	if(imprinted_effect!="heal" && role=="灵息")
		return player->get_cur_mofa()>=player->query_mofa_max() ?
			"mofa" : "";
	return player->get_cur_life()>=player->query_life_max() ? "life" : "";
}

mapping(string:mixed) query_pet_room_presence(object player)
{
	mapping result = (["active":0]);
	string species;
	mapping info;
	if(!player || !player->is || !player->is("player"))
		return result;
	refresh_pet_runtime_if_stale(player);
	refresh_pet_runtime_level_if_needed(player);
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
		"basic_skill":query_pet_basic_attack_name(species),
		"native_passive":species==PET_HIDDEN_LUAN_SPECIES ?
			"灵羽回春在PVE战斗中按节拍疗愈主人，拓印其他灵技也不会覆盖" : "",
		"runes":query_pet_runtime_runes(player,info),
		"rune_combo":query_pet_rune_combo_active(player,info),
		"rune_mode":query_pet_rune_mode_name(player),
		"rune_effect":query_pet_runtime_rune_description(player,info),
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
	refresh_pet_runtime_if_stale(player);
	refresh_pet_runtime_level_if_needed(player);
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
		"basic_skill":query_pet_basic_attack_name(species),
		"native_passive":species==PET_HIDDEN_LUAN_SPECIES ?
			"灵羽回春在PVE战斗中按节拍疗愈主人，拓印其他灵技也不会覆盖" : "",
		"runes":query_pet_runtime_runes(player,info),
		"rune_combo":query_pet_rune_combo_active(player,info),
		"rune_mode":query_pet_rune_mode_name(player),
		"rune_effect":query_pet_runtime_rune_description(player,info),
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
	if((pvp_target=="" && (int)result["cooldown_remaining"]==0) ||
	   (pvp_target!="" && (int)result["pvp_charge"]>=
		(int)result["pvp_charge_required"])) {
		string waiting_resource = query_pet_waiting_resource(player,info);
		if(waiting_resource!="")
			result["waiting_resource"] = waiting_resource;
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
	if(imprinted_effect=="damage" || imprinted_effect=="dot" ||
	   (imprinted_effect!="heal" && (role=="强攻" || role=="迅捷"))){
		int amount = base_damage*2/100*amount_percent/100*
			growth_percent/100;
		int cap = target_life_max*2/1000*growth_percent/100;
		if(amount<1) amount = 1;
		if(cap<1) cap = 1;
		if(amount>cap) amount = cap;
		result["type"] = imprinted_effect=="dot" ? "dot" : "damage";
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
	if(imprinted_effect=="damage" || imprinted_effect=="dot" ||
	   (imprinted_effect!="heal" && (role=="强攻" || role=="迅捷"))){
		int amount = base_damage*8/100*amount_percent/100*
			growth_percent/100;
		int cap = target_life_max*4/1000*growth_percent/100;
		if(amount<1) amount = 1;
		if(cap<1) cap = 1;
		if(amount>cap) amount = cap;
		result["type"] = imprinted_effect=="dot" ? "dot" : "damage";
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
		"runes":query_pet_runtime_runes(player,info),
		"rune_combo":query_pet_rune_combo_active(player,info),
		"rune_mode":query_pet_rune_mode_name(player),
		"rune_effect":query_pet_runtime_rune_description(player,info),
		"rune_set_triggered":actual>0 &&
			sizeof(query_pet_runtime_runes(player,info))==3,
		"rune_combo_triggered":actual>0 &&
			query_pet_rune_combo_active(player,info),
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

// 灵宠结算仍只在主人线程内完成；同房间广播只是客户端可识别的视觉事件。
// 主人和直接PVP对手已有完整战报，这里排除他们以避免重复动画。
private void broadcast_pet_skill_to_room(object player,object|zero direct_player,
	mapping event)
{
	object env;
	string message;
	string amount_desc = "";
	if(!player || !mappingp(event))
		return;
	env = environment(player);
	if(!env)
		return;
	if((int)event["amount"]>0){
		if(event["type"]=="damage")
			amount_desc = "，对"+(string)event["target_name"]+"造成"+
				(int)event["amount"]+"点"+
				(event["mode"]=="pvp" ? "御灵" : "协战")+"伤害";
		else if(event["type"]=="dot")
			amount_desc = "，为"+(string)event["target_name"]+
				"施加持续伤害，每跳"+(int)event["amount"]+
				"点，持续"+(int)event["duration"]+"个战斗节拍";
		else if(event["type"]=="mofa")
			amount_desc = "，为主人恢复"+(int)event["amount"]+"点法力";
		else if(event["type"]=="revive")
			amount_desc = "，在死亡前为主人恢复"+
				(int)event["amount"]+"点生命，并恢复"+
				(int)event["mofa_amount"]+"点法力";
		else
			amount_desc = "，为主人恢复"+(int)event["amount"]+"点生命";
	}
	else
		amount_desc = "，守护在主人身旁";
	message = "【灵宠显化】"+player->query_name_cn()+"的"+
		(string)(event["icon"] || "🐾")+(string)event["name"]+
		"施展「"+(string)event["skill"]+"」"+amount_desc+"。\n";
	catch {
		foreach(all_inventory(env),object observer){
			if(!observer || observer==player || observer==direct_player ||
			   !observer->is || !observer->is("player") ||
			   !LOGICALZONED->is_visible(observer,player))
				continue;
			tell_object(observer,message);
		}
	};
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
	refresh_pet_runtime_if_stale(player);
	refresh_pet_runtime_level_if_needed(player);
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
	string waiting_resource = query_pet_waiting_resource(player,info);
	if(waiting_resource!=""){
		result["ok"] = 0;
		result["amount"] = 0;
		result["waiting_resource"] = waiting_resource;
		return result;
	}
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
	else if(effect_type=="dot" && target->get_cur_life()>1){
		mapping dot_result = apply_pet_imprinted_dot(player,target,amount,"pve");
		if(dot_result["applied"]){
			actual = (int)dot_result["tick_damage"];
			result["duration"] = (int)dot_result["duration"];
			result["total_amount"] = (int)dot_result["total_amount"];
			result["source_tick"] = (int)dot_result["source_tick"];
			result["inherit_percent"] =
				(int)dot_result["inherit_percent"];
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
	if(actual<=0){
		result["ok"] = 0;
		result["amount"] = 0;
		result["waiting_target"] = 1;
		return result;
	}
	// 只有真实产生效果才进入冷却；满生命/法力时保持就绪。
	player["/tmp/wanling/assist_at"] = time();
	result["ok"] = 1;
	result["amount"] = actual;
	event = create_pet_assist_event(player,
		search(({"damage","dot"}),effect_type)!=-1 ? target : player,
		info,"pve",effect_type,
		actual,(int)result["cooldown"]);
	if(effect_type=="dot"){
		event["duration"] = (int)result["duration"];
		event["total_amount"] = (int)result["total_amount"];
	}
	player["/tmp/wanling/recent_assist"] = copy_value(event);
	result["event"] = copy_value(event);
	broadcast_pet_skill_to_room(player,0,event);
	string unit = effect_type=="damage" ? "点协战伤害" :
		(effect_type=="dot" ? "点/跳持续伤害（持续"+
		(int)result["duration"]+"个战斗节拍）" :
		(effect_type=="mofa" ? "点法力" : "点生命"));
	tell_object(player,"【万灵协战】"+
		(string)(player["/tmp/wanling/pet_name"] || info["name"])+"施展"+
		query_pet_active_skill_name(player,info)+"，带来"+actual+unit+"。\n");
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
	refresh_pet_runtime_if_stale(player);
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
	refresh_pet_runtime_level_if_needed(player);
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
	result = query_pet_pvp_assist_profile(species,
		player->query_base_damage(),target->query_life_max(),
		player->query_life_max(),player->query_mofa_max(),
		(int)player["/tmp/wanling/skill_set"],
		(int)player["/tmp/wanling/pet_pvp_growth_percent"],
		query_pet_imprinted_effect(player));
	string effect_type = (string)result["type"];
	int amount = (int)result["amount"];
	int actual = 0;
	string waiting_resource = query_pet_waiting_resource(player,info);
	if(waiting_resource!=""){
		player["/tmp/wanling/pvp_charge"] = required;
		result["ok"] = 0;
		result["amount"] = 0;
		result["waiting_resource"] = waiting_resource;
		result["charge"] = required;
		result["charge_required"] = required;
		result["uses"] = uses;
		return result;
	}
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
	else if(effect_type=="dot" && target->get_cur_life()>1){
		mapping dot_result = apply_pet_imprinted_dot(player,target,amount,"pvp");
		if(dot_result["applied"]){
			actual = (int)dot_result["tick_damage"];
			result["duration"] = (int)dot_result["duration"];
			result["total_amount"] = (int)dot_result["total_amount"];
			result["source_tick"] = (int)dot_result["source_tick"];
			result["inherit_percent"] =
				(int)dot_result["inherit_percent"];
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
	if(actual<=0){
		player["/tmp/wanling/pvp_charge"] = required;
		result["ok"] = 0;
		result["amount"] = 0;
		result["waiting_target"] = 1;
		result["charge"] = required;
		result["charge_required"] = required;
		result["uses"] = uses;
		return result;
	}
	player["/tmp/wanling/pvp_charge"] = 0;
	player["/tmp/wanling/pvp_uses"] = uses+1;
	result["ok"] = 1;
	result["amount"] = actual;
	result["uses"] = uses+1;
	event = create_pet_assist_event(player,
		search(({"damage","dot"}),effect_type)!=-1 ? target : player,
		info,"pvp",effect_type,
		actual,required);
	if(effect_type=="dot"){
		event["duration"] = (int)result["duration"];
		event["total_amount"] = (int)result["total_amount"];
	}
	event["pvp_uses"] = uses+1;
	event["pvp_uses_max"] = PET_PVP_ASSIST_USES;
	player["/tmp/wanling/recent_assist"] = copy_value(event);
	result["event"] = copy_value(event);
	broadcast_pet_skill_to_room(player,target_owner,event);
	string unit = effect_type=="damage" ? "点御灵伤害" :
		(effect_type=="dot" ? "点/跳持续伤害（持续"+
		(int)result["duration"]+"个战斗节拍）" :
		(effect_type=="mofa" ? "点法力" : "点生命"));
	tell_object(player,"【御灵交锋】"+
		(string)(player["/tmp/wanling/pet_name"] || info["name"])+"施展"+
		query_pet_active_skill_name(player,info)+"，带来"+actual+unit+"（本场"+
		(uses+1)+"/"+PET_PVP_ASSIST_USES+"）。\n");
	tell_object(target_owner,"【御灵交锋】"+player->query_name_cn()+
		"的"+(string)(player["/tmp/wanling/pet_name"] ||
			info["name"])+"施展"+query_pet_active_skill_name(player,info)+
		"。\n");
	return result;
}

/**
 * 山海万灵的「基础灵攻」：每回合（每次心跳）都可触发的免费小技能，
 * 与主灵技冷却相互独立，目的是让宠物在长战中持续可见地参与。
 * 输出量按主灵技比例折算（约 5%），不消耗任何资源、不计入 PVP 充能、
 * 不与每日目标/排行榜统计相关，避免被用来刷数据。
 */
private int basic_attack_message_throttle_sec = 3;

string query_pet_basic_attack_name(string species)
{
	mapping info;
	if(!species || species=="")
		return "";
	info = shanhai_catalog[species];
	if(!info)
		return "";
	return (string)(info["basic_attack"] || "灵爪");
}

mapping(string:mixed) perform_pet_basic_assist(object player,object target)
{
	mapping result = (["ok":0,"type":"none","amount":0]);
	string species;
	mapping info;
	mapping profile;
	string effect_type;
	int amount;
	int actual;
	int message_throttle;
	int now;
	if(!player || !target || !player->is || !player->is("player") ||
	   !target->is || !target->is("npc") ||
	   player->get_cur_life()<=0 || target->get_cur_life()<=0 ||
	   environment(player)!=environment(target) ||
	   !LOGICALZONED->can_action("combat",player,target) ||
	   SUMMOND->query_combat_credit_owner(target)!=target)
		return result;
	refresh_pet_runtime_if_stale(player);
	// PVE 专属：基础灵攻不参与 PVP，避免破坏 PVP 充能平衡。
	if(target->is("player"))
		return result;
	refresh_pet_runtime_level_if_needed(player);
	species = (string)(player["/tmp/wanling/species"] || "");
	info = shanhai_catalog[species];
	if(!info)
		return result;
	// 基础灵攻是物种天赋，不能被拓印的主动灵技覆盖。否则疗愈型鸾鸟
	// 学会伤害灵技后会永久失去回生羽之外的被动治疗。
	profile = query_pet_assist_profile(species,player->query_base_damage(),
		target->query_life_max(),player->query_life_max(),
		player->query_mofa_max(),
		(int)player["/tmp/wanling/skill_set"],
		(int)player["/tmp/wanling/pet_growth_percent"],
		// 鸾鸟是疗愈型灵宠。把固有小治疗明确锁定为 heal，避免以后
		// 调整图鉴角色或拓印类型时又把灵羽回春改成攻击效果。
		species==PET_HIDDEN_LUAN_SPECIES ? "heal" : "");
	effect_type = (string)profile["type"];
	amount = (int)profile["amount"];
	if(amount<=0 || effect_type=="none")
		return result;
	amount = amount/20;
	if(amount<1)
		amount = 1;
	actual = 0;
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
	now = time();
	// 聊天节流：每 N 秒最多发一次提示，伤害仍每 tick 结算。
	message_throttle = (int)player["/tmp/wanling/basic_msg_at"];
	result["ok"] = 1;
	result["type"] = effect_type;
	result["amount"] = actual;
	result["skill_name"] = query_pet_basic_attack_name(species);
	if(actual>0 && now>=message_throttle){
		string unit = effect_type=="damage" ? "点协战伤害" :
			(effect_type=="mofa" ? "点法力" : "点生命");
		tell_object(player,"【万灵·"+
			(string)(player["/tmp/wanling/pet_name"] || info["name"])+
			"·"+result["skill_name"]+"】带来"+actual+unit+"。\n");
		player["/tmp/wanling/basic_msg_at"] = now+
			basic_attack_message_throttle_sec;
	}
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
	   !killer || !objectp(killer))
		return 0;
	refresh_pet_runtime_if_stale(player);
	if((string)(player["/tmp/wanling/species"] || "")!=
		PET_HIDDEN_LUAN_SPECIES ||
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
	tell_object(player,"【回生羽】你的鸾鸟燃起五采灵羽，"+
		"在死亡前将你唤回（今日已使用）。\n");
	broadcast_pet_skill_to_room(player,0,event);
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
	if(SPIRIT_COMPANIOND->query_pet_battle_source(player)!="shared" ||
	   !player || !target || !target->is || !target->is("player") ||
		environment(player)!=environment(target))
		return result;
	refresh_pet_runtime_if_stale(player);
	refresh_pet_runtime_level_if_needed(player);
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
	if(profile["type"]=="dot"){
		mapping dot_profile = query_pet_imprinted_dot_profile(player,target,
			(int)profile["amount"],"pvp");
		profile["amount"] = (int)dot_profile["total_amount"];
		profile["dot_duration"] = (int)dot_profile["duration"];
		profile["dot_tick_damage"] = (int)dot_profile["tick_damage"];
		profile["dot_source_tick"] = (int)dot_profile["source_tick"];
		profile["dot_inherit_percent"] =
			(int)dot_profile["inherit_percent"];
		profile["dot"] = 1;
		profile["type"] = "damage";
	}
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
