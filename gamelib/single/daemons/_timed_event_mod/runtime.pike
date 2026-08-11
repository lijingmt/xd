private mapping|zero query_session_for_user_id(string user_id,void|int active_only)
{
	mapping|zero best = 0;
	foreach(indices(sessions),string session_key){
		mapping session = sessions[session_key];
		mapping participants = session["participants"];
		mapping participant;
		string phase;
		if(!mappingp(participants))
			continue;
		participant = participants[user_id];
		if(!mappingp(participant))
			continue;
		if(active_only){
			phase = (string)session["phase"];
			if(phase!="signup" && phase!="battle")
				continue;
			// 修复：被淘汰的玩家（alive=0）不应被视为活跃参与者
			if((int)participant["alive"]==0)
				continue;
		}
		if(!best || (int)session["created_at"]>(int)best["created_at"])
			best = session;
	}
	return best;
}

private string query_session_key(mapping session)
{
	return (string)session["event_id"]+"|"+(string)session["date"]+
		"|"+(string)session["group"];
}

private string build_session_key(string event_id,string date,string group)
{
	return event_id+"|"+date+"|"+group;
}

private mapping ensure_session(string event_id,string group,mapping window)
{
	string session_key = build_session_key(event_id,
		(string)window["date"],group);
	mapping session = sessions[session_key];
	if(mappingp(session))
		return session;
	session = ([
		"event_id":event_id,
		"date":window["date"],
		"group":group,
		"phase":"signup",
		"created_at":time(),
		"battle_start_at":window["signup_end_at"],
		"battle_end_at":window["battle_end_at"],
		"finished_at":0,
		"finish_reason":"",
		"participants":([]),
		"elimination_order":({}),
		"queue":({}),
		"duels":([]),
		"duel_counter":0,
		"sealed_until":([]),
		"seal_helpers":([]),
		"boss_node":"0",
		"boss_alive":0,
		"boss_spawned":0,
		"last_boss_move":0,
		"generals_spawned":({}),
		"general_kills":0,
		"seal_count":0,
		"last_checkpoint":time(),
	]);
	sessions[session_key] = session;
	save_event_state();
	return session;
}

private string default_return_path(object player)
{
	if(player && player->query_raceId()=="monst")
		return "/gamelib/d/jinaodao/yuhuacunguangchang";
	return "/gamelib/d/congxianzhen/congxianzhenguangchang";
}

private string safe_return_path(object player)
{
	object env = player ? environment(player) : 0;
	string path;
	if(!env)
		return default_return_path(player);
	path = file_name(env);
	if(!path || search(path,"#")!=-1 ||
	   search(path,ROOT+"/gamelib/d/")!=0 ||
	   FBD->is_fb_room_path(path) || is_event_room(env))
		return default_return_path(player);
	return path-ROOT;
}

int is_event_room(object room)
{
	return room && functionp(room->is_timed_event_room) &&
		room->is_timed_event_room();
}

private int internal_move_player(object player,object room)
{
	int moved;
	mixed move_err;
	if(!player || !room)
		return 0;
	player["/tmp/timed_event_move_bypass"] = 1;
	move_err = catch { moved = player->move(room); };
	player->m_delete_foruser("/tmp/timed_event_move_bypass");
	if(!move_err && moved && functionp(player->reset_view))
		player->reset_view();
	return !move_err && moved && environment(player)==room;
}

private string event_ingress_path(string event_id)
{
	if(event_id==EVENT_TIANHENG)
		return "/gamelib/d/timed_event/tianheng_ingress.pike";
	if(event_id==EVENT_JIUYAO)
		return "/gamelib/d/timed_event/jiuyao_ingress.pike";
	return "";
}

/**
 * Request a normal fenced move to a reconstructable event ingress. A remote
 * move reports logical success while the gateway saves/retires this copy; a
 * local move really lands in the room. Both cases are intentionally accepted.
 */
private int route_player_to_event_ingress(object player,string event_id)
{
	string path = event_ingress_path(event_id);
	object room;
	int moved;
	mixed move_err;
	if(!player || path=="")
		return 0;
	move_err = catch { room = (object)(ROOT+path); };
	if(move_err || !room)
		return 0;
	player["/tmp/timed_event_move_bypass"] = 1;
	move_err = catch { moved = player->move(room); };
	player->m_delete_foruser("/tmp/timed_event_move_bypass");
	return !move_err && moved;
}

int guard_player_move(object player,mixed destination)
{
	object env;
	int destination_is_event = 0;
	if(!player || player["/tmp/timed_event_move_bypass"])
		return 0;
	if(objectp(destination))
		destination_is_event = is_event_room(destination);
	else if(stringp(destination) &&
	   (has_prefix((string)destination,ROOT+"/gamelib/d/timed_event/") ||
	    has_prefix((string)destination,"/gamelib/d/timed_event/")))
		destination_is_event = 1;
	if(destination_is_event){
		tell_object(player,"限时秘境只能通过活动集结通道进入。\n");
		return 1;
	}
	env = environment(player);
	if(!is_event_room(env))
		return 0;
	tell_object(player,"限时秘境已锁定空间，不能飞行、传送或跟随离开；可使用活动页的安全退出。\n");
	return 1;
}

private object ensure_event_room(mapping session,string node,string kind)
{
	string session_key = query_session_key(session);
	mapping one_session_rooms = runtime_rooms[session_key];
	object room;
	string room_name = "限时秘境";
	string room_desc = "天衡司以阵纹暂时隔绝了外界。\n";
	if(!mappingp(one_session_rooms)){
		one_session_rooms = ([]);
		runtime_rooms[session_key] = one_session_rooms;
	}
	room = one_session_rooms[node];
	if(room)
		return room;
	room = clone(ROOT+"/gamelib/d/timed_event/event_room.pike");
	if((string)session["event_id"]==EVENT_TIANHENG){
		if(kind=="pvp_lobby"){
			room_name = "天衡候场台";
			room_desc = "四面悬镜尚未点亮，参赛者可在开战前选择战势。\n";
		}
		else if(kind=="pvp_stage"){
			room_name = "天衡绝境";
			room_desc = "四道衡门不断换位，踏入任一衡门都会被随机配入一处镜域。\n";
		}
		else{
			room_name = "天衡镜域·"+(string)session["duel_counter"];
			room_desc = "镜域只承载交锋双方及其所属灵兽，外人无法进入。\n";
		}
	}
	else{
		array(string) names = ({"玄枢台","星槎径","青阙门",
			"金衡道","九曜心","赤轮道","沧渊门","月隐径","天纪台"});
		int index = (int)node;
		if(kind=="pve_lobby"){
			room_name = "九曜集结台";
			room_desc = "九曜阵尚未落定，参与者可在此阅读规则并等待开阵。\n";
		}
		else if(index>=0 && index<sizeof(names))
			room_name = names[index];
		if(kind!="pve_lobby")
			room_desc = "曜脉在脚下明灭，封脉可以改变渊主的巡游路线。\n";
	}
	room->configure_timed_event_room((string)session["event_id"],
		session_key,node,kind,room_name,room_desc);
	one_session_rooms[node] = room;
	return room;
}

private void destroy_session_runtime(mapping session)
{
	string session_key = query_session_key(session);
	mapping one_session_rooms = runtime_rooms[session_key];
	array npcs = runtime_npcs[session_key];
	if(arrayp(npcs))
		foreach(npcs,object npc)
			if(npc)
				destruct(npc);
	if(mappingp(one_session_rooms))
		foreach(values(one_session_rooms),object room)
			if(room)
				destruct(room);
	m_delete(runtime_npcs,session_key);
	m_delete(runtime_rooms,session_key);
}

private void clean_event_fight(object player)
{
	object opponent;
	mixed opponent_targets;
	if(!player)
		return;
	opponent = player->enemy;
	if(player->query_in_combat())
		player->_clean_fight();
	if(opponent){
		opponent->clean_targets(player);
		opponent_targets = opponent->get_all_targets();
		if(opponent->query_in_combat() &&
		   (!arrayp(opponent_targets) || sizeof(opponent_targets)==0))
			opponent->_clean_fight();
	}
}

private int count_alive(mapping session)
{
	int alive = 0;
	foreach(values((mapping)session["participants"]),mapping participant)
		if((int)participant["alive"])
			alive++;
	return alive;
}

private array(string) query_alive_ids(mapping session)
{
	array(string) result = ({});
	foreach(indices((mapping)session["participants"]),string user_id)
		if((int)session["participants"][user_id]["alive"])
			result += ({user_id});
	sort(result);
	return result;
}

private mapping normalize_player_event_state(object player)
{
	mapping state = player[PLAYER_EVENT_ROOT];
	if(!mappingp(state))
		state = ([]);
	if(!mappingp(state["last_entry"]))
		state["last_entry"] = ([]);
	if(!mappingp(state["claims"]))
		state["claims"] = ([]);
	if(!mappingp(state["badges"]))
		state["badges"] = ([]);
	if((int)state["tianheng_tokens"]<0)
		state["tianheng_tokens"] = 0;
	if((int)state["jiuyao_tokens"]<0)
		state["jiuyao_tokens"] = 0;
	player[PLAYER_EVENT_ROOT] = state;
	return state;
}

private void mark_player_entry(object player,string event_id,string date)
{
	mapping state;
	if(!player)
		return;
	state = normalize_player_event_state(player);
	state["last_entry"][event_id] = date;
}

private int player_already_entered(object player,string event_id,string date)
{
	mapping state;
	mapping last_entry;
	if(!player)
		return 1;
	// HTTP /api/status 会调用此路径，必须保持纯读取，不能在轮询线程补档。
	state = player[PLAYER_EVENT_ROOT];
	last_entry = mappingp(state) && mappingp(state["last_entry"]) ?
		state["last_entry"] : ([]);
	// 淘汰记录不能继续把玩家当作活跃会话，但今日资格仍已消费。
	// 否则同日多场次或未来调整日程后可重复领取参与奖励。
	if((string)last_entry[event_id]==date)
		return 1;
	foreach(values(sessions),mapping session)
		if((string)session["event_id"]==event_id &&
		   (string)session["date"]==date){
			mapping participant = session["participants"][(string)player->query_name()];
			if(mappingp(participant) && (string)session["phase"]!="signup")
				return 1;
		}
	return 0;
}

private mapping build_reward(int level,string event_id,string result,int rank)
{
	int base_exp;
	int base_money;
	int multiplier = 1;
	int tokens = 1;
	string message;
	if(level<1)
		level = 1;
	base_exp = level*level*3+500;
	base_money = level*200+1000;
	if(event_id==EVENT_TIANHENG){
		if(rank==1){ multiplier = 5; tokens = 12; }
		else if(rank==2){ multiplier = 3; tokens = 8; }
		else if(rank==3){ multiplier = 2; tokens = 5; }
		message = rank>0 && rank<=3 ?
			"天衡绝境第"+(string)rank+"名奖励" : "天衡绝境参与奖励";
	}
	else{
		if(result=="victory"){ multiplier = 4; tokens = 8; }
		else if(result=="failure"){ multiplier = 2; tokens = 2; }
		message = result=="victory" ? "九曜镇渊成功奖励" :
			(result=="failure" ? "九曜镇渊守关奖励" : "九曜镇渊参与奖励");
	}
	return (["exp":base_exp*multiplier,"money":base_money*multiplier,
		"tokens":tokens,"message":message]);
}

private void prepare_participant_reward(mapping session,string user_id,
	string result,int rank)
{
	mapping participant = session["participants"][user_id];
	if(!mappingp(participant) || mappingp(participant["reward"]))
		return;
	participant["rank"] = rank;
	participant["reward"] = build_reward((int)participant["level"],
		(string)session["event_id"],result,rank);
}

private int claim_participant_reward(mapping session,string user_id,
	object player)
{
	mapping participant = session["participants"][user_id];
	mapping reward;
	mapping state;
	mapping claims;
	mapping receipt;
	string claim_id;
	int actual_exp = 0;
	int save_ok = 1;
	int newly_credited = 0;
	if(!player || !mappingp(participant) ||
	   (int)participant["reward_claimed"] ||
	   !mappingp(participant["reward"]))
		return 0;
	reward = participant["reward"];
	state = normalize_player_event_state(player);
	claims = state["claims"];
	claim_id = query_session_key(session);
	receipt = claims[claim_id];
	if(!mappingp(receipt)){
		newly_credited = 1;
		if((int)reward["exp"]>0)
			actual_exp = player->add_exp_with_bonus((int)reward["exp"]);
		if((int)reward["money"]>0)
			player->add_account((int)reward["money"]);
		if((string)session["event_id"]==EVENT_TIANHENG)
			state["tianheng_tokens"] = (int)state["tianheng_tokens"]+
				(int)reward["tokens"];
		else
			state["jiuyao_tokens"] = (int)state["jiuyao_tokens"]+
				(int)reward["tokens"];
		receipt = (["created_at":time(),"actual_exp":actual_exp]);
		claims[claim_id] = receipt;
		while(sizeof(claims)>64){
			array(string) claim_ids = indices(claims);
			string oldest_id = claim_ids[0];
			foreach(claim_ids,string one_id)
				if((int)claims[one_id]["created_at"]<
				   (int)claims[oldest_id]["created_at"])
					oldest_id = one_id;
			m_delete(claims,oldest_id);
		}
		player->query_if_levelup();
	}
	else
		actual_exp = (int)receipt["actual_exp"];
	if((string)player->sid!="5dwap"){
		if(!functionp(player->save_with_result))
			save_ok = 0;
		else
			save_ok = player->save_with_result();
	}
	if(!save_ok){
		tell_object(player,"活动奖励已进入待保存状态，系统会在存档成功后自动确认，请勿重复操作。\n");
		return 0;
	}
	// The player receipt is the anti-duplication authority. Once that record is
	// durable, report the credit even if the owner's global acknowledgement
	// needs a later retry.
	if(newly_credited)
		tell_object(player,"【"+(string)reward["message"]+"】经验+"+
			(string)actual_exp+"，金币+"+(string)reward["money"]+
			"，活动令+"+(string)reward["tokens"]+"。\n");
	if(MAP_WORKERD->query_node_role()=="worker" &&
	   !local_timed_event_owner()){
		if(!stage_reward_claim_ack(session,user_id))
			return newly_credited;
		participant["reward_claimed"] = 1;
	}
	else{
		participant["reward_claimed"] = 1;
		if(!save_event_state()){
			participant["reward_claimed"] = 0;
			return newly_credited;
		}
	}
	return 1;
}

private void claim_all_pending(object player)
{
	string user_id;
	if(!player)
		return;
	user_id = player->query_name();
	foreach(values(sessions),mapping session)
		claim_participant_reward(session,user_id,player);
}

private void return_player_from_event(object player,mapping participant)
{
	string path;
	object|zero target = 0;
	mixed err;
	if(!player)
		return;
	clean_event_fight(player);
	path = mappingp(participant) ? (string)participant["return_path"] : "";
	if(path=="" || search(path,"#")!=-1)
		path = default_return_path(player);
	err = catch{ target = (object)(ROOT+path); };
	if(err || !target || is_event_room(target) || FBD->is_fb_room_path(file_name(target))){
		path = default_return_path(player);
		target = (object)(ROOT+path);
	}
	internal_move_player(player,target);
	player->last_pos = path;
	player->set_life(player->query_life_max());
	player->set_mofa(player->query_mofa_max());
}

int restore_player(object player)
{
	mapping session;
	mapping participant;
	object room;
	string node;
	if(!player)
		return 0;
	refresh_readonly_event_snapshot();
	claim_all_pending(player);
	session = query_session_for_user_id(player->query_name(),1);
	if(!session)
		return 0;
	if(MAP_WORKERD->query_node_role()=="worker" &&
	   !local_timed_event_owner())
		return route_player_to_event_ingress(player,
			(string)session["event_id"]);
	participant = session["participants"][player->query_name()];
	if(!mappingp(participant)){
		werror("[timed_event] restore_player failed: %s not in session participants\n",
			player->query_name());
		return 0;
	}
	if(!(int)participant["alive"]){
		werror("[timed_event] restore_player failed: %s is eliminated (alive=0), cleaning up stale record\n",
			player->query_name());
		return 0;
	}
	participant["disconnected_at"] = 0;
	node = (string)participant["room_node"];
	if(node=="")
		node = (string)session["event_id"]==EVENT_TIANHENG ? "lobby" : "4";
	if((string)session["event_id"]==EVENT_TIANHENG)
		room = ensure_event_room(session,node,
			node=="lobby" ? "pvp_lobby" :
			(node=="stage" ? "pvp_stage" : "pvp_duel"));
	else
		room = ensure_event_room(session,node,"pve_node");
	if(!internal_move_player(player,room))
		return 0;
	tell_object(player,"你已重新接入"+query_event_name((string)session["event_id"])+"。\n");
	save_event_state();
	return 1;
}

mapping(string:mixed) query_runtime_counts()
{
	return (["sessions":sizeof(sessions),"room_groups":sizeof(runtime_rooms),
		"npc_groups":sizeof(runtime_npcs)]);
}
