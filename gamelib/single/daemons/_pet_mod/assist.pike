/** 低频PVE协战；不参与人物PVP，不生成灵宠NPC。 */

#ifndef XIAND_PET_ASSIST_PIKE
#define XIAND_PET_ASSIST_PIKE

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
	player["/tmp/wanling/assist_at"] = time();
	result["ok"] = 1;
	result["amount"] = actual;
	if(actual>0){
		string unit = effect_type=="damage" ? "点协战伤害" :
			(effect_type=="mofa" ? "点法力" : "点生命");
		tell_object(player,"【万灵协战】"+(string)info["name"]+"施展"+
			(string)info["skill"]+"，带来"+actual+unit+"。\n");
	}
	return result;
}

#endif
