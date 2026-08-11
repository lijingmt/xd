/** 3—5人万灵裂隙、公开招募、回合机制、个人奖励与周保底。 */

#ifndef XIAND_PET_RIFT_PIKE
#define XIAND_PET_RIFT_PIKE

private string new_runtime_pet_id()
{
	for(int attempt=0;attempt<30;attempt++){
		string candidate = String.string2hex(
			Crypto.Random.random_string(32));
		int used = 0;
		foreach(rift_sessions;string team_id;mapping session){
			if(session && session["id"]==candidate){
				used = 1;
				break;
			}
		}
		if(!used){
			foreach(duel_invites;string target_id;mapping invite){
				if(invite && invite["token"]==candidate){
					used = 1;
					break;
				}
			}
		}
		if(!used)
			return candidate;
	}
	return "";
}

private void clean_expired_pet_runtime_unlocked()
{
	int now = time();
	foreach(indices(rift_sessions),string team_id){
		mapping session = rift_sessions[team_id];
		if(!session || (int)session["expires_at"]<now)
			m_delete(rift_sessions,team_id);
	}
	foreach(indices(rift_recruits),string leader_id){
		mapping recruit = rift_recruits[leader_id];
		if(!recruit || (int)recruit["expires_at"]<now ||
		   !find_player(leader_id))
			m_delete(rift_recruits,leader_id);
	}
	foreach(indices(duel_invites),string target_id){
		mapping invite = duel_invites[target_id];
		if(!invite || (int)invite["expires_at"]<now)
			m_delete(duel_invites,target_id);
	}
}

mapping(string:mixed) open_rift_recruit(object player)
{
	mapping result = pet_result(0,"没有开启招募。 ");
	string player_id;
	string term_id;
	object key;
	if(!player || player->query_level()<PET_STARTER_LEVEL)
		return pet_result(0,"达到15级并开启万灵谱后才能招募裂隙队伍。 ");
	mapping pet_state = query_pet_state(player);
	if(!pet_state["ok"] || !(int)pet_state["starter_claimed"])
		return pet_result(0,"请先完成15级万灵初契，再发布裂隙招募。 ");
	player_id = player->query_name();
	term_id = player->query_term();
	if(term_id!="" && term_id!="noterm" &&
	   TERMD->get_term_power(term_id,player_id)!="leader")
		return pet_result(0,"只有队长可以发布万灵裂隙招募。 ");
	key = pet_lock->lock();
	clean_expired_pet_runtime_unlocked();
	rift_recruits[player_id] = ([
		"leader_id":player_id,
		"leader_name":player->query_name_cn(),
		"created_at":time(),
		"expires_at":time()+600,
	]);
	destruct(key);
	array players = users();
	for(int i=0;i<sizeof(players);i++){
		object viewer = players[i];
		if(!viewer || viewer==player || !viewer->is ||
		   !viewer->is("player") ||
		   !LOGICALZONED->can_interact(player,viewer))
			continue;
		tell_object(viewer,"【万灵裂隙招募】"+player->query_name_cn()+
			"正在召集3—5人探索队。\n[一键加入:wanling_join "+
			player_id+"]\n");
	}
	result = pet_result(1,"招募已发布10分钟；同逻辑区玩家可一键入队。 ");
	result["leader_id"] = player_id;
	return result;
}

mapping(string:mixed) join_rift_recruit(object player,string leader_id)
{
	mapping result = pet_result(0,"未能加入裂隙队伍。 ");
	object leader;
	string term_id;
	object key;
	if(!player || !leader_id || player->query_name()==leader_id)
		return result;
	if(player->query_level()<PET_STARTER_LEVEL)
		return pet_result(0,"达到15级并完成万灵初契后才能加入裂隙队伍。 ");
	mapping pet_state = query_pet_state(player);
	if(!pet_state["ok"] || !(int)pet_state["starter_claimed"])
		return pet_result(0,"请先完成万灵初契，再加入裂隙队伍。 ");
	leader = find_player(leader_id);
	if(!leader || !LOGICALZONED->can_interact(player,leader))
		return pet_result(0,"招募者已离线或位于隔离区。 ");
	if(player->query_term()!="" && player->query_term()!="noterm")
		return pet_result(0,"你已经在其他队伍中，请先处理当前队伍。 ");
	key = pet_lock->lock();
	clean_expired_pet_runtime_unlocked();
	if(!rift_recruits[leader_id]){
		destruct(key);
		return pet_result(0,"这条裂隙招募已经关闭或过期。 ");
	}
	term_id = leader->query_term();
	if(term_id=="" || term_id=="noterm")
		term_id = TERMD->term_create(leader_id);
	if(sizeof(term_id)<=1){
		destruct(key);
		return pet_result(0,"建立队伍失败，请重新发布招募。 ");
	}
	int add_result = TERMD->add_termer(term_id,
		player->query_name(),player->query_name_cn());
	if(add_result==1)
		result = pet_result(1,"你已加入万灵裂隙队伍；请与队长在同一房间集合。 ");
	else if(add_result==2)
		result["message"] = "队伍已经达到5人上限。";
	else
		result["message"] = "加入失败，招募状态可能已经变化。";
	destruct(key);
	return result;
}

private array(string) query_valid_rift_members(object leader)
{
	array(string) members = ({});
	string term_id = leader->query_term();
	mapping term;
	if(term_id=="" || term_id=="noterm" || !TERMD->query_termId(term_id))
		return members;
	term = TERMD->query_term_m(term_id);
	foreach(indices(term),string member_id){
		object member = find_player(member_id);
		if(!member || member->query_term()!=term_id ||
		   environment(member)!=environment(leader) ||
		   !LOGICALZONED->can_interact(leader,member) ||
		   member->get_cur_life()<=0 ||
		   member->query_level()<PET_STARTER_LEVEL)
			continue;
		members += ({member_id});
	}
	return members;
}

private string rift_mechanic_for_round(int round,int hp,int hp_max)
{
	if(hp>0 && hp*100<=hp_max*15)
		return "capture";
	switch((round-1)%4){
		case 0: return "break";
		case 1: return "guard";
		case 2: return "heal";
	}
	return "seal";
}

string query_rift_mechanic_name(string mechanic)
{
	if(mechanic=="break") return "破阵：合力击碎灵障";
	if(mechanic=="guard") return "截怒：守御分担冲击";
	if(mechanic=="heal") return "净息：疗愈并清理浊气";
	if(mechanic=="seal") return "循序封印：稳定灵脉";
	if(mechanic=="capture") return "缚灵：生命低于15%后合力结契";
	return "未知灵潮";
}

mapping(string:mixed) start_rift(object leader)
{
	mapping result = pet_result(0,"万灵裂隙没有开启。 ");
	string term_id;
	array(string) members;
	string session_id;
	string boss_species;
	mapping contributions = ([]);
	object key;
	if(!leader)
		return result;
	term_id = leader->query_term();
	if(term_id=="" || term_id=="noterm" ||
	   !TERMD->query_termId(term_id))
		return pet_result(0,"万灵裂隙需要真实的3—5人队伍。 ");
	if(TERMD->get_term_power(term_id,leader->query_name())!="leader")
		return pet_result(0,"只有队长可以开启裂隙。 ");
	members = query_valid_rift_members(leader);
	if(sizeof(members)<PET_RIFT_MIN_MEMBERS ||
	   sizeof(members)>PET_RIFT_MAX_MEMBERS)
		return pet_result(0,"请让3—5名15级以上队员活着在同一房间集合。 ");
	key = pet_lock->lock();
	clean_expired_pet_runtime_unlocked();
	mapping(string:string) participant_account_ids = ([]);
	foreach(members,string member_id){
		object member = find_player(member_id);
		string member_account = resolve_pet_account(member);
		mapping member_record;
		if(member_account==""){
			destruct(key);
			return pet_result(0,"队员的注册账号异常，暂时无法开启裂隙。 ");
		}
		member_record = load_pet_record_unlocked(member_account);
		if(!member_record || !(int)member_record["starter_claimed"]){
			destruct(key);
			return pet_result(0,"每位队员都需要先完成15级万灵初契。 ");
		}
		// 同一注册账号的不同角色可以分别占据行动位，
		// 但万灵档案本来就按账号共享，后续仍每场每账号一份奖励。
		participant_account_ids[member_id] = member_account;
	}
	if(rift_sessions[term_id]){
		if((string)rift_sessions[term_id]["status"]!="lost"){
			result = pet_result(1,"队伍已有进行中或待领取的裂隙。 ");
			result["session"] = copy_value(rift_sessions[term_id]);
			destruct(key);
			return result;
		}
		m_delete(rift_sessions,term_id);
	}
	session_id = new_runtime_pet_id();
	if(session_id==""){
		destruct(key);
		return pet_result(0,"无法生成安全的裂隙会话，请稍后重试。 ");
	}
	boss_species = query_weekly_boss_species();
	foreach(members,string member_id)
		contributions[member_id] = ([
			"damage":0,"guard":0,"heal":0,"control":0,"actions":0,
		]);
	int hp_max = sizeof(members)*850;
	rift_sessions[term_id] = ([
		"id":session_id,
		"team_id":term_id,
		"leader_id":leader->query_name(),
		"boss_species":boss_species,
		"participants":members,
		"participant_accounts":participant_account_ids,
		"room":environment(leader),
		"hp":hp_max,
		"hp_max":hp_max,
		"spirit":100,
		"round":1,
		"mechanic":rift_mechanic_for_round(1,hp_max,hp_max),
		"actions":([]),
		"claimed":([]),
		"contributions":contributions,
		"status":"active",
		"captured":0,
		"created_at":time(),
		"expires_at":time()+PET_RIFT_EXPIRE_SECONDS,
		"last_message":"裂隙开启，第一道灵障正在聚合。",
	]);
	m_delete(rift_recruits,leader->query_name());
	result = pet_result(1,"万灵裂隙已经开启。 ");
	result["session"] = copy_value(rift_sessions[term_id]);
	destruct(key);
	TERMD->term_tell(term_id,"【万灵裂隙】本周异兽 "+
		(string)shanhai_catalog[boss_species]["name"]+
		"现身。每轮每人选择一次行动。\n[查看战局:wanling_rift]\n");
	return result;
}

private string find_player_rift_team_unlocked(string player_id)
{
	foreach(rift_sessions;string team_id;mapping session){
		if(session && search((array)session["participants"],player_id)!=-1)
			return team_id;
	}
	return "";
}

/**
 * 掉线或离开房间的成员不能永久卡住整队。保留至少3名有效玩家时缩编继续，
 * 少于3名则立即安全失败；离队者不再参与本场个人奖励。
 */
private void reconcile_rift_participants_unlocked(mapping session)
{
	if(!session || (string)session["status"]!="active")
		return;
	array(string) active = ({});
	foreach((array)session["participants"],string player_id){
		object player = find_player(player_id);
		if(player && player->get_cur_life()>0 &&
		   environment(player)==(object)session["room"] &&
		   LOGICALZONED->can_user_action("team",
			(string)session["leader_id"],player_id))
			active += ({player_id});
	}
	if(sizeof(active)==sizeof((array)session["participants"]))
		return;
	session["participants"] = active;
	foreach(indices((mapping)session["actions"]),string player_id)
		if(search(active,player_id)==-1)
			m_delete(session["actions"],player_id);
	if(sizeof(active)<PET_RIFT_MIN_MEMBERS){
		session["status"] = "lost";
		session["last_message"] =
			"有效探索成员不足3人，本场已安全结束，可重新集合后挑战。";
	}
}

mapping(string:mixed) query_rift_state(object player)
{
	mapping result = pet_result(0,"当前没有进行中的万灵裂隙。 ");
	string account_id;
	string team_id;
	object key;
	if(!player)
		return result;
	account_id = resolve_pet_account(player);
	key = pet_lock->lock();
	clean_expired_pet_runtime_unlocked();
	team_id = find_player_rift_team_unlocked(player->query_name());
	if(team_id!=""){
		reconcile_rift_participants_unlocked(rift_sessions[team_id]);
		result = copy_value(rift_sessions[team_id]);
		result["ok"] = 1;
		result["message"] = "";
		result["acted"] = !!result["actions"][player->query_name()];
	}
	else if(account_id!=""){
		mapping(string:mixed)|zero record =
			load_pet_record_unlocked(account_id);
		if(record){
			int changed = refresh_pet_periods_unlocked(record);
			if(changed && (int)record["persisted"])
				save_pet_record_unlocked(record);
			mapping pending = newest_pending_rift_unlocked(record);
			if(sizeof(pending))
				result = ([
					"ok":1,"message":"","pending":1,
					"id":pending["id"],
					"boss_species":pending["boss_species"],
					"status":"won","round":PET_RIFT_MAX_ROUNDS,
					"hp":0,"hp_max":0,"spirit":0,
					"mechanic":"capture","actions":([]),
					"participants":({player->query_name()}),
					"contributions":([player->query_name():([])]),
					"acted":1,
					"last_message":"你有一份已持久化的裂隙个人奖励，服务器重启后仍可领取。",
				]);
		}
	}
	destruct(key);
	return result;
}

private int rift_required_success(int member_count)
{
	return (member_count+1)/2;
}

private mapping(string:mixed) newest_pending_rift_unlocked(mapping record)
{
	mapping result = ([]);
	int newest = 0;
	foreach((mapping)record["pending_rift_rewards"];
	   string session_id;mapping reward){
		if((int)reward["won_at"]>=newest){
			newest = (int)reward["won_at"];
			result = copy_value(reward);
			result["id"] = session_id;
		}
	}
	return result;
}

/** 胜利资格先逐账号原子保存，进程重启后仍可领取。 */
private int queue_rift_rewards_unlocked(mapping session)
{
	int queued = 0;
	if((int)session["reward_queued"])
		return sizeof((array)session["participants"]);
	foreach((array)session["participants"],string player_id){
		object player = find_player(player_id);
		string account_id = resolve_pet_account(player);
		mapping(string:mixed)|zero record;
		if(account_id=="")
			continue;
		record = load_pet_record_unlocked(account_id);
		if(!record)
			continue;
		refresh_pet_periods_unlocked(record);
		if(record["rewarded_sessions"][(string)session["id"]] ||
		   record["pending_rift_rewards"][(string)session["id"]]){
			queued++;
			continue;
		}
		record["pending_rift_rewards"][(string)session["id"]] = ([
			"boss_species":(string)session["boss_species"],
			"won_at":time(),
			"expires_at":time()+PET_PENDING_REWARD_SECONDS,
		]);
		record["revision"] = (int)record["revision"]+1;
		if(save_pet_record_unlocked(record))
			queued++;
	}
	if(queued==sizeof((array)session["participants"]))
		session["reward_queued"] = 1;
	return queued;
}

private void tell_rift_participants(mapping session,string message)
{
	foreach((array)session["participants"],string player_id){
		object player = find_player(player_id);
		if(player && LOGICALZONED->can_user_action(
		   "team",(string)session["leader_id"],player_id))
			tell_object(player,message);
	}
}

// 裂隙奖励存在共享万灵档案中。同账号多角色参战时，任一角色
// 成功领取即代表该账号的全部参战位已领，避免重复发奖，也避免
// 未能达到participants数而把已结算会话永久卡住。
private void mark_rift_account_claimed_unlocked(mapping session,
	string account_id)
{
	mapping accounts;
	if(!session || account_id=="")
		return;
	accounts = mappingp(session["participant_accounts"]) ?
		(mapping)session["participant_accounts"] : ([]);
	foreach((array)session["participants"],string player_id){
		string participant_account = (string)accounts[player_id];
		if(participant_account=="")
			participant_account = (string)
				ACCOUNT_CHARACTERD->query_account_id_for_character(player_id);
		if(participant_account==account_id)
			session["claimed"][player_id] = 1;
	}
	if(sizeof((mapping)session["claimed"])>=
	   sizeof((array)session["participants"]))
		m_delete(rift_sessions,(string)session["team_id"]);
}

private void resolve_rift_round_unlocked(mapping session)
{
	string expected = (string)session["mechanic"];
	mapping actions = session["actions"];
	int member_count = sizeof((array)session["participants"]);
	int matched = 0;
	int damage = 0;
	int guards = 0;
	int heals = 0;
	int seals = 0;
	int captures = 0;
	foreach(actions;string player_id;mixed raw_action){
		string action = (string)raw_action;
		mapping contribution = session["contributions"][player_id];
		int one_damage = 0;
		if(action=="break") one_damage = 130;
		else if(action=="guard"){
			one_damage = 75;
			guards++;
			contribution["guard"] = (int)contribution["guard"]+1;
		}
		else if(action=="heal"){
			one_damage = 55;
			heals++;
			contribution["heal"] = (int)contribution["heal"]+1;
		}
		else if(action=="seal"){
			one_damage = 90;
			seals++;
			contribution["control"] = (int)contribution["control"]+1;
		}
		else if(action=="capture"){
			one_damage = 35;
			captures++;
			contribution["control"] = (int)contribution["control"]+1;
		}
		if(action==expected)
			matched++;
		damage += one_damage;
		contribution["damage"] = (int)contribution["damage"]+one_damage;
		contribution["actions"] = (int)contribution["actions"]+1;
	}
	string round_message = "第"+(int)session["round"]+"轮：";
	if(expected=="capture" && captures>=2){
		session["captured"] = 1;
		session["status"] = "won";
		session["hp"] = 1;
		round_message += "两道以上缚灵印同时落下，异兽平静接受灵契！";
	}
	else{
		if(matched>=rift_required_success(member_count)){
			damage += member_count*60;
			round_message += "机制应对成功，灵障显露破绽。";
		}
		else{
			session["spirit"] = (int)session["spirit"]-12;
			round_message += "应对不足，队伍灵息受损。";
		}
		if(expected=="guard")
			session["spirit"] = (int)session["spirit"]+guards*3;
		else if(expected=="heal")
			session["spirit"] = (int)session["spirit"]+heals*4;
		else if(expected=="seal" && seals==0)
			session["spirit"] = (int)session["spirit"]-8;
		session["spirit"] = (int)session["spirit"]-
			(8-guards*2>3 ? 8-guards*2 : 3);
		if((int)session["spirit"]>100)
			session["spirit"] = 100;
		if((int)session["spirit"]<0)
			session["spirit"] = 0;
		session["hp"] = (int)session["hp"]-damage;
		// 缚灵阶段必须至少两人同时结契，不能继续输出绕过机制。
		if(expected=="capture" && captures<2 &&
		   (int)session["hp"]<=0)
			session["hp"] = 1;
		if((int)session["hp"]<0)
			session["hp"] = 0;
		if((int)session["hp"]<=0){
			session["status"] = "won";
			round_message += " 异兽灵障尽散，裂隙平复！";
		}
		else if((int)session["spirit"]<=0 ||
		        (int)session["round"]>=PET_RIFT_MAX_ROUNDS){
			session["status"] = "lost";
			round_message += " 队伍灵息耗尽，本次探索结束。";
		}
		else{
			session["round"] = (int)session["round"]+1;
			session["mechanic"] = rift_mechanic_for_round(
				(int)session["round"],(int)session["hp"],
				(int)session["hp_max"]);
			session["actions"] = ([]);
			round_message += " 下一轮："+query_rift_mechanic_name(
				(string)session["mechanic"])+"。";
		}
	}
	if((string)session["status"]=="won"){
		int queued = queue_rift_rewards_unlocked(session);
		if(queued<sizeof((array)session["participants"]))
			round_message += " 部分领奖资格保存失败，请留在战局页重试领取。";
	}
	session["last_message"] = round_message;
	tell_rift_participants(session,"【万灵裂隙】"+round_message+
		"\n[继续查看:wanling_rift]\n");
}

mapping(string:mixed) take_rift_action(object player,string action)
{
	mapping result = pet_result(0,"裂隙行动没有生效。 ");
	string team_id;
	mapping session;
	object key;
	if(search(({"break","guard","heal","seal","capture"}),action)==-1)
		return pet_result(0,"请选择破阵、守御、疗愈、封印或缚灵。 ");
	key = pet_lock->lock();
	clean_expired_pet_runtime_unlocked();
	team_id = find_player_rift_team_unlocked(player->query_name());
	if(team_id==""){
		destruct(key);
		return result;
	}
	session = rift_sessions[team_id];
	reconcile_rift_participants_unlocked(session);
	if((string)session["status"]!="active")
		result["message"] = "本次裂隙已经结算，请领取个人奖励。";
	else if(environment(player)!=(object)session["room"] ||
	        !LOGICALZONED->can_user_action("team",
			(string)session["leader_id"],player->query_name()))
		result["message"] = "你已离开探索房间或逻辑分区，不能提交本轮行动。";
	else if(session["actions"][player->query_name()])
		result["message"] = "你本轮已经行动，请等待其他队员。";
	else if(action=="capture" && (string)session["mechanic"]!="capture")
		result["message"] = "异兽生命尚未进入15%缚灵区间。";
	else{
		session["actions"][player->query_name()] = action;
		result = pet_result(1,"本轮行动已记录。 ");
		result["waiting"] = sizeof((array)session["participants"])-
			sizeof((mapping)session["actions"]);
		if((int)result["waiting"]<=0)
			resolve_rift_round_unlocked(session);
		result["session"] = copy_value(session);
	}
	destruct(key);
	return result;
}

mapping(string:mixed) claim_rift_reward(object player,
	void|int test_pet_roll,void|int test_cosmetic_roll)
{
	mapping result = pet_result(0,"没有可领取的裂隙奖励。 ");
	string account_id = resolve_pet_account(player);
	string team_id = "";
	mapping session = ([]);
	int runtime_session = 0;
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="")
		return result;
	key = pet_lock->lock();
	clean_expired_pet_runtime_unlocked();
	team_id = find_player_rift_team_unlocked(player->query_name());
	if(team_id!=""){
		mapping active_session = rift_sessions[team_id];
		if((string)active_session["status"]=="won"){
			session = active_session;
			runtime_session = 1;
		}
	}
	record = load_pet_record_unlocked(account_id);
	if(!record)
		result["message"] = "万灵谱数据异常，奖励暂未领取。";
	else{
		refresh_pet_periods_unlocked(record);
		if(!sizeof(session)){
			mapping pending = newest_pending_rift_unlocked(record);
			if(sizeof(pending))
				session = ([
					"id":pending["id"],
					"boss_species":pending["boss_species"],
					"status":"won",
				]);
		}
		if(!sizeof(session)){
			if(team_id!="" &&
			   (string)rift_sessions[team_id]["status"]=="lost")
				result["message"] = "本次探索未能平复裂隙，没有胜利奖励。";
			else if(team_id!="")
				result["message"] = "裂隙仍在进行中。";
		}
		else if(record["rewarded_sessions"][(string)session["id"]]){
			if(runtime_session)
				mark_rift_account_claimed_unlocked(session,account_id);
			result["message"] = "这个账号已经领取过本场个人奖励。";
		}
		else{
			add_pet_material_unlocked(record,"spirit_mark",5);
			add_pet_material_unlocked(record,"spirit_dew",4);
			add_pet_material_unlocked(record,"egg_fragment",2);
			add_pet_material_unlocked(record,"bond_token",1);
			record["daily"]["rift"] = 1;
			record["weekly"]["rift_wins"] =
				(int)record["weekly"]["rift_wins"]+1;
			record["rift_pity"] = (int)record["rift_pity"]+1;
			int pet_roll = random(10000);
			int cosmetic_roll = random(10000);
			if(search(account_id,"testunit")!=-1){
				if(!zero_type(test_pet_roll))
					pet_roll = test_pet_roll;
				if(!zero_type(test_cosmetic_roll))
					cosmetic_roll = test_cosmetic_roll;
			}
			if((int)record["rift_pity"]>=30)
				pet_roll = 0;
			mapping acquisition = ([]);
			if(pet_roll<100){
				acquisition = acquire_pet_unlocked(record,
					(string)session["boss_species"],"rift_egg");
				record["rift_pity"] = 0;
			}
			int cosmetic = 0;
			if(cosmetic_roll<10){
				int pet_index = find_species_index(record["pets"],
					(string)session["boss_species"]);
				if(pet_index>=0){
					array variants = record["pets"][pet_index]["variants"];
					if(search(variants,"月华异色")==-1)
						record["pets"][pet_index]["variants"] += ({"月华异色"});
				}
				else
					add_pet_material_unlocked(record,"cosmetic_dust",10);
				cosmetic = 1;
			}
			record["rewarded_sessions"][(string)session["id"]] = time();
			m_delete(record["pending_rift_rewards"],(string)session["id"]);
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record)){
				result = pet_result(1,"获得5枚灵印、4滴灵露、2枚灵卵残片和1枚同心叶。 ");
				result["pet_acquisition"] = copy_value(acquisition);
				result["cosmetic"] = cosmetic;
				result["weekly_wins"] = record["weekly"]["rift_wins"];
				if(runtime_session)
					mark_rift_account_claimed_unlocked(session,account_id);
			}
			else
				result["message"] = "奖励保存失败，本次仍可重试领取。";
		}
	}
	destruct(key);
	return result;
}

mapping(string:mixed) claim_pet_weekly_choice(object player,string choice)
{
	mapping result = pet_result(0,"周目标奖励没有领取。 ");
	string account_id = resolve_pet_account(player);
	mapping(string:mixed)|zero record;
	object key;
	if(account_id=="" ||
	   search(({"fragment","rune","cosmetic"}),choice)==-1)
		return result;
	key = pet_lock->lock();
	record = load_pet_record_unlocked(account_id);
	if(record){
		refresh_pet_periods_unlocked(record);
		if((int)record["weekly"]["rift_wins"]<3)
			result["message"] = "本周平复3次万灵裂隙后才可三选一。";
		else if((int)record["weekly"]["choice_claimed"])
			result["message"] = "本周万灵奖励已经选择过。";
		else{
			string message;
			if(choice=="fragment"){
				add_pet_material_unlocked(record,"egg_fragment",12);
				message = "领取了12枚灵卵残片。";
			}
			else if(choice=="rune"){
				add_pet_material_unlocked(record,"skill_rune",2);
				message = "领取了2枚灵纹符。";
			}
			else{
				add_pet_material_unlocked(record,"cosmetic_dust",20);
				message = "领取了20份月华尘，只用于外观。";
			}
			record["weekly"]["choice_claimed"] = 1;
			record["revision"] = (int)record["revision"]+1;
			if(save_pet_record_unlocked(record))
				result = pet_result(1,message);
		}
	}
	destruct(key);
	return result;
}

/** 只供TestUnit模拟Pike进程重启丢失运行时裂隙。 */
void drop_test_rift_runtime(string account_id)
{
	if(search(account_id,"testunit")==-1)
		return;
	object key = pet_lock->lock();
	foreach(indices(rift_sessions),string team_id){
		mapping session = rift_sessions[team_id];
		int matched = 0;
		foreach((array)(session && session["participants"] || ({})),
		   string player_id){
			if(ACCOUNT_CHARACTERD->query_account_id_for_character(player_id)==
			   account_id){
				matched = 1;
				break;
			}
		}
		if(matched)
			m_delete(rift_sessions,team_id);
	}
	destruct(key);
}

#endif
