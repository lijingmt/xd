/** 标准化三宠论道：同房邀请、三局两胜、单局最多12回合与防刷奖励。 */

#ifndef XIAND_PET_DUEL_PIKE
#define XIAND_PET_DUEL_PIKE

private mapping(string:mixed) normalized_duel_pet(mapping pet,int borrowed)
{
	string species = (string)pet["species"];
	mapping info = shanhai_catalog[species];
	return ([
		"id":borrowed ? "borrowed-"+species : (string)pet["id"],
		"species":species,
		"name":mappingp(pet["fusion"]) &&
			(string)pet["fusion"]["name"]!="" ?
			(string)pet["fusion"]["name"] : (string)info["name"],
		"role":(string)info["role"],
		"family":(string)info["family"],
		"skills":copy_value(pet["skills"] || info["skill_sets"][0]),
		"borrowed":borrowed,
	]);
}

private array(mapping(string:mixed)) build_duel_roster_unlocked(
	mapping record,string character_id)
{
	array(mapping(string:mixed)) roster = ({});
	multiset(string) used_species = (<>);
	array selected = record["duel_teams"][character_id] || ({});
	foreach(selected,mixed raw_id){
		string pet_id = (string)raw_id;
		int index = find_pet_index(record["pets"],pet_id);
		if(index<0)
			continue;
		mapping pet = record["pets"][index];
		string species = (string)pet["species"];
		if(used_species[species])
			continue;
		roster += ({normalized_duel_pet(pet,0)});
		used_species[species] = 1;
		if(sizeof(roster)>=3)
			return roster;
	}
	// 未主动编队时先采用已收录伙伴。
	foreach((array)record["pets"],mapping pet){
		string species = (string)pet["species"];
		if(used_species[species])
			continue;
		roster += ({normalized_duel_pet(pet,0)});
		used_species[species] = 1;
		if(sizeof(roster)>=3)
			return roster;
	}
	// 新账号不会因收藏不足被拒之门外；借宠只有标准化论道属性。
	foreach(starter_species,string species){
		if(used_species[species])
			continue;
		mapping borrowed = ([
			"id":"borrowed-"+species,
			"species":species,
			"skills":copy_value(shanhai_catalog[species]["skill_sets"][0]),
		]);
		roster += ({normalized_duel_pet(borrowed,1)});
		used_species[species] = 1;
		if(sizeof(roster)>=3)
			break;
	}
	return roster;
}

private int pet_family_advantage(string attacker,string defender)
{
	mapping(string:string) counters = ([
		"火":"金","金":"木","木":"土","土":"水","水":"火",
		"风":"灵","灵":"雷","雷":"风",
	]);
	return counters[attacker]==defender;
}

private int pet_role_attack(string role)
{
	if(role=="强攻") return 145;
	if(role=="迅捷") return 125;
	if(role=="灵息") return 115;
	if(role=="疗愈") return 100;
	return 105;
}

private int pet_role_damage_reduction(string role)
{
	return role=="守护" ? 20 : 0;
}

private mapping(string:mixed) simulate_pet_bout(mapping left,mapping right,
	int bout)
{
	int left_hp = 1000;
	int right_hp = 1000;
	int round = 0;
	array(string) highlights = ({});
	for(round=1;round<=12;round++){
		int left_damage = pet_role_attack((string)left["role"]);
		int right_damage = pet_role_attack((string)right["role"]);
		if(pet_family_advantage((string)left["family"],
		   (string)right["family"]))
			left_damage = left_damage*115/100;
		if(pet_family_advantage((string)right["family"],
		   (string)left["family"]))
			right_damage = right_damage*115/100;
		left_damage = left_damage*(100-
			pet_role_damage_reduction((string)right["role"]))/100;
		right_damage = right_damage*(100-
			pet_role_damage_reduction((string)left["role"]))/100;
		// 迅捷者在偶数回合形成小幅先手优势；无随机命中与付费属性。
		if((string)left["role"]=="迅捷" && round%2==0)
			left_damage += 20;
		if((string)right["role"]=="迅捷" && round%2==0)
			right_damage += 20;
		right_hp -= left_damage;
		left_hp -= right_damage;
		if((string)left["role"]=="疗愈" && left_hp>0){
			left_hp += 35;
			if(left_hp>1000) left_hp = 1000;
		}
		if((string)right["role"]=="疗愈" && right_hp>0){
			right_hp += 35;
			if(right_hp>1000) right_hp = 1000;
		}
		if(round==1 || round==6 || left_hp<=0 || right_hp<=0)
			highlights += ({"第"+round+"回合 "+
				(string)left["name"]+" "+(left_hp>0?left_hp:0)+
				" / "+(string)right["name"]+" "+
				(right_hp>0?right_hp:0)});
		if(left_hp<=0 || right_hp<=0)
			break;
	}
	int winner = 0;
	if(left_hp>right_hp) winner = 1;
	else if(right_hp>left_hp) winner = 2;
	return ([
		"bout":bout,
		"left":copy_value(left),
		"right":copy_value(right),
		"left_hp":left_hp>0 ? left_hp : 0,
		"right_hp":right_hp>0 ? right_hp : 0,
		"rounds":round>12 ? 12 : round,
		"winner":winner,
		"highlights":highlights,
	]);
}

private mapping(string:mixed) simulate_pet_match(
	array(mapping(string:mixed)) left,
	array(mapping(string:mixed)) right)
{
	array(mapping(string:mixed)) bouts = ({});
	int left_wins = 0;
	int right_wins = 0;
	int draws = 0;
	for(int i=0;i<3;i++){
		mapping bout = simulate_pet_bout(left[i],right[i],i+1);
		bouts += ({bout});
		if((int)bout["winner"]==1) left_wins++;
		else if((int)bout["winner"]==2) right_wins++;
		else draws++;
	}
	int winner = 0;
	if(left_wins>right_wins) winner = 1;
	else if(right_wins>left_wins) winner = 2;
	return ([
		"winner":winner,
		"left_wins":left_wins,
		"right_wins":right_wins,
		"draws":draws,
		"bouts":bouts,
	]);
}

mapping(string:mixed) test_simulate_pet_match(string left_species,
	string right_species)
{
	array(mapping(string:mixed)) left = ({});
	array(mapping(string:mixed)) right = ({});
	if(!shanhai_catalog[left_species] || !shanhai_catalog[right_species])
		return ([]);
	for(int i=0;i<3;i++){
		mapping left_pet = ([
			"id":"test-left-"+i,"species":left_species,
			"skills":copy_value(shanhai_catalog[left_species]["skill_sets"][0]),
		]);
		mapping right_pet = ([
			"id":"test-right-"+i,"species":right_species,
			"skills":copy_value(shanhai_catalog[right_species]["skill_sets"][0]),
		]);
		left += ({normalized_duel_pet(left_pet,1)});
		right += ({normalized_duel_pet(right_pet,1)});
	}
	return simulate_pet_match(left,right);
}

mapping(string:mixed) invite_pet_duel(object challenger,string target_id)
{
	object target;
	string challenger_account;
	string target_account;
	string token;
	mapping(string:mixed)|zero challenger_record;
	mapping(string:mixed)|zero target_record;
	object key;
	if(!challenger || !target_id || challenger->query_name()==target_id)
		return pet_result(0,"不能向自己发起灵宠论道。 ");
	target = find_player(target_id);
	if(!target || environment(target)!=environment(challenger) ||
	   !LOGICALZONED->can_interact(challenger,target))
		return pet_result(0,"只能邀请同房间、同逻辑区的在线玩家。 ");
	if(challenger->query_level()<PET_STARTER_LEVEL ||
	   target->query_level()<PET_STARTER_LEVEL)
		return pet_result(0,"双方达到15级后才能进行灵宠论道。 ");
	challenger_account = resolve_pet_account(challenger);
	target_account = resolve_pet_account(target);
	if(challenger_account=="" || target_account=="")
		return pet_result(0,"无法核验双方注册账号。 ");
	if(lower_case(challenger_account)==lower_case(target_account))
		return pet_result(0,"同一注册账号下的角色不能互相论道或取得奖励。 ");
	key = pet_lock->lock();
	clean_expired_pet_runtime_unlocked();
	challenger_record = load_pet_record_unlocked(challenger_account);
	target_record = load_pet_record_unlocked(target_account);
	if(!challenger_record || !target_record ||
	   !(int)challenger_record["starter_claimed"] ||
	   !(int)target_record["starter_claimed"]){
		destruct(key);
		return pet_result(0,"双方都完成15级万灵初契后才能进行论道。 ");
	}
	token = new_runtime_pet_id();
	if(token==""){
		destruct(key);
		return pet_result(0,"无法生成安全的论道邀请，请稍后重试。 ");
	}
	duel_invites[target_id] = ([
		"token":token,
		"challenger_id":challenger->query_name(),
		"challenger_name":challenger->query_name_cn(),
		"target_id":target_id,
		"created_at":time(),
		"expires_at":time()+PET_INVITE_EXPIRE_SECONDS,
	]);
	destruct(key);
	tell_object(target,"【灵宠论道邀请】"+challenger->query_name_cn()+
		"邀请你进行标准化三宠论道。无人物死亡、物品损失或红名。\n"+
		"[接受:pet_duel accept "+challenger->query_name()+" "+token+"] "+
		"[拒绝:pet_duel refuse "+challenger->query_name()+" "+token+"]\n");
	mapping result = pet_result(1,"论道邀请已发出，2分钟内有效。 ");
	result["token"] = token;
	return result;
}

mapping(string:mixed) query_pet_duel_invite(object target)
{
	mapping result = ([]);
	object key;
	if(!target)
		return result;
	key = pet_lock->lock();
	clean_expired_pet_runtime_unlocked();
	if(duel_invites[target->query_name()])
		result = copy_value(duel_invites[target->query_name()]);
	destruct(key);
	return result;
}

mapping(string:mixed) refuse_pet_duel(object target,string challenger_id,
	string token)
{
	object key;
	if(!target)
		return pet_result(0,"论道邀请不存在。 ");
	key = pet_lock->lock();
	clean_expired_pet_runtime_unlocked();
	mapping invite = duel_invites[target->query_name()];
	if(!invite || invite["challenger_id"]!=challenger_id ||
	   invite["token"]!=token){
		destruct(key);
		return pet_result(0,"论道邀请不存在或已经过期。 ");
	}
	m_delete(duel_invites,target->query_name());
	destruct(key);
	object challenger = find_player(challenger_id);
	if(challenger)
		tell_object(challenger,target->query_name_cn()+"婉拒了本次灵宠论道。\n");
	return pet_result(1,"你婉拒了本次灵宠论道。 ");
}

private int apply_duel_record_unlocked(mapping record,string opponent_account,
	int outcome)
{
	array opponents = record["daily"]["opponents"];
	if(search(opponents,opponent_account)!=-1 ||
	   sizeof(opponents)>=PET_DUEL_DAILY_OPPONENTS)
		return 0;
	record["daily"]["opponents"] += ({opponent_account});
	if(outcome==1){
		add_pet_material_unlocked(record,"spirit_mark",6);
		record["season"]["wins"] = (int)record["season"]["wins"]+1;
	}
	else if(outcome==2){
		add_pet_material_unlocked(record,"spirit_mark",5);
		record["season"]["losses"] = (int)record["season"]["losses"]+1;
	}
	else{
		add_pet_material_unlocked(record,"spirit_mark",5);
		record["season"]["draws"] = (int)record["season"]["draws"]+1;
	}
	record["revision"] = (int)record["revision"]+1;
	return 1;
}

string query_pet_duel_season_title(mapping season)
{
	int wins = (int)season["wins"];
	if(wins>=30) return "山海知音";
	if(wins>=15) return "万灵行者";
	if(wins>=5) return "初契使者";
	return "论道学徒";
}

mapping(string:mixed) accept_pet_duel(object target,string challenger_id,
	string token)
{
	mapping result = pet_result(0,"论道没有开始。 ");
	object challenger;
	string target_account;
	string challenger_account;
	mapping(string:mixed)|zero target_record;
	mapping(string:mixed)|zero challenger_record;
	object key;
	if(!target)
		return result;
	challenger = find_player(challenger_id);
	if(!challenger || environment(challenger)!=environment(target) ||
	   !LOGICALZONED->can_interact(challenger,target))
		return pet_result(0,"邀请者已离开当前房间或逻辑分区。 ");
	target_account = resolve_pet_account(target);
	challenger_account = resolve_pet_account(challenger);
	if(target_account=="" || challenger_account=="" ||
	   lower_case(target_account)==lower_case(challenger_account))
		return pet_result(0,"双方账号核验失败或属于同一注册账号。 ");
	key = pet_lock->lock();
	clean_expired_pet_runtime_unlocked();
	mapping invite = duel_invites[target->query_name()];
	if(!invite || invite["challenger_id"]!=challenger_id ||
	   invite["token"]!=token){
		destruct(key);
		return pet_result(0,"论道邀请不存在、已使用或已经过期。 ");
	}
	target_record = load_pet_record_unlocked(target_account);
	challenger_record = load_pet_record_unlocked(challenger_account);
	if(!target_record || !challenger_record){
		destruct(key);
		return pet_result(0,"一方万灵谱数据异常，本次论道已安全取消。 ");
	}
	if(!(int)target_record["starter_claimed"] ||
	   !(int)challenger_record["starter_claimed"]){
		destruct(key);
		return pet_result(0,"一方尚未完成万灵初契，本次论道已安全取消。 ");
	}
	refresh_pet_periods_unlocked(target_record);
	refresh_pet_periods_unlocked(challenger_record);
	array(mapping(string:mixed)) challenger_roster =
		build_duel_roster_unlocked(challenger_record,challenger_id);
	array(mapping(string:mixed)) target_roster =
		build_duel_roster_unlocked(target_record,target->query_name());
	if(sizeof(challenger_roster)!=3 || sizeof(target_roster)!=3){
		destruct(key);
		return pet_result(0,"标准试炼编队补位失败，本次没有结算。 ");
	}
	mapping match = simulate_pet_match(challenger_roster,target_roster);
	int challenger_outcome = (int)match["winner"]==1 ? 1 :
		((int)match["winner"]==2 ? 2 : 0);
	int target_outcome = (int)match["winner"]==2 ? 1 :
		((int)match["winner"]==1 ? 2 : 0);
	int challenger_rewarded = apply_duel_record_unlocked(
		challenger_record,lower_case(target_account),challenger_outcome);
	int target_rewarded = apply_duel_record_unlocked(
		target_record,lower_case(challenger_account),target_outcome);
	int challenger_saved = save_pet_record_unlocked(challenger_record);
	int target_saved = save_pet_record_unlocked(target_record);
	if(!challenger_saved || !target_saved){
		// 日对手名单使重试最多补齐缺失一方，不会向已保存账号重复发灵印。
		result["message"] = "一方论道记录保存失败；已保存一方不会因重试重复领奖。";
	}
	else{
		m_delete(duel_invites,target->query_name());
		result = pet_result(1,"三局两胜论道已经结算。 ");
		result["match"] = copy_value(match);
		result["challenger_rewarded"] = challenger_rewarded;
		result["target_rewarded"] = target_rewarded;
		result["challenger_title"] = query_pet_duel_season_title(
			challenger_record["season"]);
		result["target_title"] = query_pet_duel_season_title(
			target_record["season"]);
	}
	destruct(key);
	if(result["ok"]){
		string summary = "【灵宠论道】"+challenger->query_name_cn()+" "+
			(int)match["left_wins"]+":"+(int)match["right_wins"]+" "+
			target->query_name_cn()+"。";
		if((int)match["winner"]==1)
			summary += " 胜者："+challenger->query_name_cn()+"。";
		else if((int)match["winner"]==2)
			summary += " 胜者："+target->query_name_cn()+"。";
		else
			summary += " 双方战平。";
		summary += "\n胜方首次对手奖励6灵印，参与方5灵印；重复对手不发奖励。\n"+
			"[查看万灵谱:pet]\n";
		tell_object(challenger,summary);
		tell_object(target,summary);
	}
	return result;
}

#endif
