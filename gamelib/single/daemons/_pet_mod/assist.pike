/** 低频PVE协战；不参与人物PVP，不生成灵宠NPC。 */

#ifndef XIAND_PET_ASSIST_PIKE
#define XIAND_PET_ASSIST_PIKE

/**
 * 返回战斗小窗需要的轻量陪伴状态。
 *
 * 这里只读取人物临时状态和内存图鉴，不读取账号文件，避免每秒战斗
 * 轮询触发磁盘访问。recent_event 最多保留10秒，客户端按事件ID去重。
 */
mapping(string:mixed) query_pet_battle_presence(object player)
{
	mapping result = (["active":0]);
	string species;
	mapping info;
	mapping recent;
	int skill_set;
	int cooldown;
	int assisted_at;
	int remaining;
	int event_at;
	if(!player)
		return result;
	species = (string)(player["/tmp/wanling/species"] || "");
	info = shanhai_catalog[species];
	if(!info)
		return result;
	skill_set = (int)player["/tmp/wanling/skill_set"];
	cooldown = skill_set==1 ? 24 : (skill_set==2 ? 36 : PET_ASSIST_COOLDOWN);
	assisted_at = (int)player["/tmp/wanling/assist_at"];
	remaining = assisted_at+cooldown-time();
	if(remaining<0)
		remaining = 0;
	result = ([
		"active":1,
		"pet_id":(string)(player["/tmp/wanling/pet_id"] || ""),
		"species":species,
		"name":(string)info["name"],
		"icon":(string)info["icon"],
		"family":(string)info["family"],
		"role":(string)info["role"],
		"skill":(string)info["skill"],
		"skill_set":skill_set,
		"cooldown":cooldown,
		"cooldown_remaining":remaining,
		"ready_at":assisted_at+cooldown,
	]);
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
	int player_mofa_max,void|int skill_set)
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
	result["cooldown"] = cooldown;
	string role = (string)info["role"];
	if(role=="强攻" || role=="迅捷"){
		int amount = base_damage*2/100*amount_percent/100;
		int cap = target_life_max*2/1000;
		if(amount<1) amount = 1;
		if(cap<1) cap = 1;
		if(amount>cap) amount = cap;
		result["type"] = "damage";
		result["amount"] = amount;
	}
	else if(role=="灵息"){
		int amount = player_mofa_max*2/100*amount_percent/100;
		if(amount<1) amount = 1;
		result["type"] = "mofa";
		result["amount"] = amount;
	}
	else{
		int amount = player_life_max*2/100*amount_percent/100;
		if(amount<1) amount = 1;
		result["type"] = "heal";
		result["amount"] = amount;
	}
	return result;
}

mapping(string:mixed) perform_pet_pve_assist(object player,object target)
{
	mapping result = (["ok":0,"type":"none","amount":0]);
	string species;
	mapping info;
	string target_name;
	mapping event;
	int event_seq;
	int event_at;
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
		(int)player["/tmp/wanling/skill_set"]);
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
		if(player->query_debuff("curse",0)=="life"){
			int heal_reduce = (int)player->query_debuff("curse",1);
			if(heal_reduce<0)
				heal_reduce = 0;
			if(heal_reduce>90)
				heal_reduce = 90;
			amount = amount*(100-heal_reduce)/100;
		}
		int after = before+amount;
		if(after>player->query_life_max())
			after = player->query_life_max();
		if(after>before){
			player->set_life(after);
			actual = after-before;
		}
	}
	// 即使当前生命/法力已满也进入冷却，避免每个心跳反复判断和刷屏。
	event_at = time();
	player["/tmp/wanling/assist_at"] = event_at;
	result["ok"] = 1;
	result["amount"] = actual;
	target_name = target->query_name();
	if(functionp(target->query_name_cn) && target->query_name_cn()!="")
		target_name = target->query_name_cn();
	event_seq = (int)player["/tmp/wanling/assist_seq"]+1;
	player["/tmp/wanling/assist_seq"] = event_seq;
	event = ([
		"id":sprintf("%s-%d-%d-%d",player->query_name(),event_at,event_seq,
			random(1000000)),
		"event_at":event_at,
		"pet_id":(string)(player["/tmp/wanling/pet_id"] || ""),
		"species":species,
		"name":(string)info["name"],
		"icon":(string)info["icon"],
		"family":(string)info["family"],
		"role":(string)info["role"],
		"skill":(string)info["skill"],
		"type":effect_type,
		"amount":actual,
		"target_name":target_name,
		"cooldown":(int)result["cooldown"],
		"ready_at":event_at+(int)result["cooldown"],
	]);
	player["/tmp/wanling/recent_assist"] = event;
	result["event"] = copy_value(event);
	if(actual>0){
		string unit = effect_type=="damage" ? "点协战伤害" :
			(effect_type=="mofa" ? "点法力" : "点生命");
		tell_object(player,"【万灵协战】"+(string)info["name"]+"施展"+
			(string)info["skill"]+"，带来"+actual+unit+"。\n");
	}
	else
		tell_object(player,"【万灵协战】"+(string)info["name"]+"施展"+
			(string)info["skill"]+"，守护在你身旁。\n");
	return result;
}

#endif
