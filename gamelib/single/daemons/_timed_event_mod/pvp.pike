private string stance_name(string stance)
{
	if(stance=="feng") return "锋势";
	if(stance=="shou") return "守势";
	return "变势";
}

private void apply_tianheng_stance(object player,object opponent,string stance,
	string opponent_stance)
{
	int amount;
	if(!player || !opponent)
		return;
	if(stance=="feng"){
		amount = opponent->query_life_max()*2/100;
		if(opponent_stance=="shou")
			amount /= 2;
		if(amount<1)
			amount = 1;
		if(opponent->get_cur_life()-amount<1)
			amount = opponent->get_cur_life()-1;
		if(amount>0)
			opponent->set_life(opponent->get_cur_life()-amount);
	}
	else if(stance=="shou"){
		amount = player->query_life_max()*4/100;
		player->set_life(player->get_cur_life()+amount);
		if(player->get_cur_life()>player->query_life_max())
			player->set_life(player->query_life_max());
	}
	else{
		amount = player->query_mofa_max()*10/100;
		player->set_mofa(player->get_cur_mofa()+amount);
		if(player->get_cur_mofa()>player->query_mofa_max())
			player->set_mofa(player->query_mofa_max());
	}
}

private void recover_tianheng_winner(object winner,string stance)
{
	int life_gain;
	int mofa_gain;
	if(!winner || stance!="bian")
		return;
	life_gain = winner->query_life_max()*6/100;
	mofa_gain = winner->query_mofa_max()*6/100;
	winner->set_life(winner->get_cur_life()+life_gain);
	if(winner->get_cur_life()>winner->query_life_max())
		winner->set_life(winner->query_life_max());
	winner->set_mofa(winner->get_cur_mofa()+mofa_gain);
	if(winner->get_cur_mofa()>winner->query_mofa_max())
		winner->set_mofa(winner->query_mofa_max());
}

private array(string) clean_tianheng_queue(mapping session)
{
	array(string) result = ({});
	array queue = session["queue"];
	foreach(queue,string user_id){
		mapping participant = session["participants"][user_id];
		object player = find_player(user_id);
		if(mappingp(participant) && (int)participant["alive"] &&
		   (string)participant["duel_id"]=="" && player &&
		   is_event_room(environment(player)) &&
		   search(result,user_id)==-1)
			result += ({user_id});
	}
	session["queue"] = result;
	return result;
}

private void match_tianheng_queue(mapping session)
{
	int changed = 0;
	int before_size = sizeof((array)session["queue"]);
	array(string) queue = clean_tianheng_queue(session);
	if(sizeof(queue)!=before_size)
		changed = 1;
	while(sizeof(queue)>=2 && (string)session["phase"]=="battle"){
		changed = 1;
		int first_index = random(sizeof(queue));
		string first_id = queue[first_index];
		queue -= ({first_id});
		int second_index = random(sizeof(queue));
		string second_id = queue[second_index];
		queue -= ({second_id});
		mapping first_participant = session["participants"][first_id];
		mapping second_participant = session["participants"][second_id];
		object first = find_player(first_id);
		object second = find_player(second_id);
		string duel_id;
		object duel_room;
		if(!first || !second)
			continue;
		session["duel_counter"] = (int)session["duel_counter"]+1;
		duel_id = "duel_"+(string)session["duel_counter"];
		first_participant["duel_id"] = duel_id;
		second_participant["duel_id"] = duel_id;
		first_participant["room_node"] = duel_id;
		second_participant["room_node"] = duel_id;
		session["duels"][duel_id] = ([
			"first":first_id,"second":second_id,"started_at":time(),
		]);
		duel_room = ensure_event_room(session,duel_id,"pvp_duel");
		internal_move_player(first,duel_room);
		internal_move_player(second,duel_room);
		apply_tianheng_stance(first,second,
			(string)first_participant["stance"],
			(string)second_participant["stance"]);
		apply_tianheng_stance(second,first,
			(string)second_participant["stance"],
			(string)first_participant["stance"]);
		tell_object(first,"衡镜闭合，你以"+
			stance_name((string)first_participant["stance"])+
			"迎战"+second->query_name_cn()+"。\n");
		tell_object(second,"衡镜闭合，你以"+
			stance_name((string)second_participant["stance"])+
			"迎战"+first->query_name_cn()+"。\n");
		first->kill_flag = 1;
		second->kill_flag = 1;
		first->kill(second,0);
		if(!second->query_in_combat())
			second->_fight(first);
	}
	session["queue"] = queue;
	if(changed)
		save_event_state();
}

private void finish_tianheng(mapping session,string reason)
{
	array(string) alive_ids = query_alive_ids(session);
	array(string) ordered = ({});
	while(sizeof(alive_ids)){
		string best_id = alive_ids[0];
		int best_score = -1;
		foreach(alive_ids,string user_id){
			mapping participant = session["participants"][user_id];
			object player = find_player(user_id);
			int life_rate = player ? player->get_cur_life()*1000/
				(player->query_life_max() || 1) : 0;
			int score = (int)participant["wins"]*100000+life_rate;
			if(score>best_score || (score==best_score && user_id<best_id)){
				best_id = user_id;
				best_score = score;
			}
		}
		ordered += ({best_id});
		alive_ids -= ({best_id});
	}
	for(int i=0;i<sizeof(ordered);i++)
		prepare_participant_reward(session,ordered[i],"finished",i+1);
	foreach(indices((mapping)session["participants"]),string user_id){
		mapping participant = session["participants"][user_id];
		object player = find_player(user_id);
		if(!mappingp(participant["reward"]))
			prepare_participant_reward(session,user_id,"finished",
				(int)participant["rank"]);
		if(player){
			/* 单个玩家的回迁/发奖失败绝不能中断整个结算循环，
			 * 否则其余玩家会被困在已销毁的活动动态房里（本地
			 * 多worker天衡实测：结算途中崩溃→全员黑屏滞留）。 */
			mixed settle_err = catch {
				return_player_from_event(player,participant);
				claim_participant_reward(session,user_id,player);
			};
			if(settle_err)
				werror("[TIMED_EVENT_SETTLE] user=%s error=%s\n",
					user_id,describe_error(settle_err)[..180]);
		}
	}
	session["phase"] = "finished";
	session["finished_at"] = time();
	session["finish_reason"] = reason;
	destroy_session_runtime(session);
	save_event_state();
}

private void eliminate_tianheng(mapping session,string loser_id,
	object|zero winner,string reason)
{
	mapping loser_participant = session["participants"][loser_id];
	object loser = find_player(loser_id);
	string duel_id;
	int rank;
	if(!mappingp(loser_participant) || !(int)loser_participant["alive"])
		return;
	duel_id = (string)loser_participant["duel_id"];
	loser_participant["alive"] = 0;
	loser_participant["eliminated_at"] = time();
	loser_participant["eliminate_reason"] = reason;
	loser_participant["duel_id"] = "";
	session["queue"] -= ({loser_id});
	session["elimination_order"] += ({loser_id});
	rank = count_alive(session)+1;
	loser_participant["rank"] = rank;
	prepare_participant_reward(session,loser_id,"eliminated",rank);
	if(loser){
		clean_event_fight(loser);
		return_player_from_event(loser,loser_participant);
		claim_participant_reward(session,loser_id,loser);
		tell_object(loser,"你已离开天衡绝境，今日不能再次入场。\n");
	}
	if(winner){
		string winner_id = winner->query_name();
		mapping winner_participant = session["participants"][winner_id];
		if(mappingp(winner_participant) && (int)winner_participant["alive"]){
			clean_event_fight(winner);
			winner_participant["wins"] = (int)winner_participant["wins"]+1;
			winner_participant["duel_id"] = "";
			winner_participant["room_node"] = "stage";
			winner_participant["last_action"] = time();
			recover_tianheng_winner(winner,
				(string)winner_participant["stance"]);
			internal_move_player(winner,
				ensure_event_room(session,"stage","pvp_stage"));
			tell_object(winner,"镜域散去，你返回天衡台等待下一轮。\n");
		}
	}
	if(duel_id!="")
		m_delete(session["duels"],duel_id);
	if(count_alive(session)<=1)
		finish_tianheng(session,"last_survivor");
	else
		save_event_state();
}

private int queue_tianheng_move(mapping session,object player,string direction)
{
	mapping participant;
	array(string) valid_directions = ({"north","east","south","west"});
	if(search(valid_directions,direction)==-1)
		return 0;
	participant = session["participants"][player->query_name()];
	if(!mappingp(participant) || !(int)participant["alive"] ||
	   (string)participant["duel_id"]!="" || player->query_in_combat())
		return 0;
	if((string)participant["room_node"]!="stage")
		return 0;
	participant["last_action"] = time();
	if(search((array)session["queue"],player->query_name())==-1)
		session["queue"] += ({player->query_name()});
	tell_object(player,"你踏入不断换位的衡门，系统正在随机配对对手。\n");
	match_tianheng_queue(session);
	save_event_state();
	return 1;
}

private void start_tianheng(mapping session)
{
	mapping config = query_event_config(EVENT_TIANHENG);
	array(string) accepted = ({});
	foreach(indices((mapping)session["participants"]),string user_id){
		object player = find_player(user_id);
		if(player && LOGICALZONED->query_user_group(user_id)==
		   (string)session["group"])
			accepted += ({user_id});
		else
			m_delete(session["participants"],user_id);
	}
	if(sizeof(accepted)<(int)config["minimum_players"]){
		foreach(accepted,string user_id){
			object player = find_player(user_id);
			mapping participant = session["participants"][user_id];
			if(player){
				return_player_from_event(player,participant);
				tell_object(player,"天衡绝境报名人数不足，本场取消且不消耗今日资格。\n");
			}
		}
		session["phase"] = "cancelled";
		session["finished_at"] = time();
		session["finish_reason"] = "not_enough_players";
		destroy_session_runtime(session);
		save_event_state();
		return;
	}
	session["phase"] = "battle";
	foreach(accepted,string user_id){
		object player = find_player(user_id);
		mapping participant = session["participants"][user_id];
		participant["alive"] = 1;
		participant["room_node"] = "stage";
		participant["last_action"] = time();
		mark_player_entry(player,EVENT_TIANHENG,(string)session["date"]);
		player->set_life(player->query_life_max());
		player->set_mofa(player->query_mofa_max());
		internal_move_player(player,
			ensure_event_room(session,"stage","pvp_stage"));
		tell_object(player,"【天衡绝境】衡门开启。主动移动会进入随机镜域；长时间不动也会被天衡收束自动配对。\n");
	}
	save_event_state();
}

private void tick_tianheng(mapping session,int now)
{
	mapping config = query_event_config(EVENT_TIANHENG);
	array(string) alive_ids = query_alive_ids(session);
	foreach(alive_ids,string user_id){
		mapping participant = session["participants"][user_id];
		object player = find_player(user_id);
		if(LOGICALZONED->query_user_group(user_id)!=(string)session["group"]){
			object|zero zone_winner = 0;
			string zone_duel_id = (string)participant["duel_id"];
			if(zone_duel_id!="" && mappingp(session["duels"][zone_duel_id])){
				mapping zone_duel = session["duels"][zone_duel_id];
				string zone_other_id = (string)zone_duel["first"]==user_id ?
					(string)zone_duel["second"] : (string)zone_duel["first"];
				zone_winner = find_player(zone_other_id);
			}
			eliminate_tianheng(session,user_id,zone_winner,
				"logical_zone_changed");
			if((string)session["phase"]!="battle")
				return;
			continue;
		}
		if(!player){
			if(!(int)participant["disconnected_at"])
				participant["disconnected_at"] = now;
			else if(now-(int)participant["disconnected_at"]>=
			   (int)config["offline_grace_seconds"]){
				object|zero winner = 0;
				string duel_id = (string)participant["duel_id"];
				if(duel_id!="" && mappingp(session["duels"][duel_id])){
					mapping duel = session["duels"][duel_id];
					string other_id = (string)duel["first"]==user_id ?
						(string)duel["second"] : (string)duel["first"];
					winner = find_player(other_id);
				}
				eliminate_tianheng(session,user_id,winner,"offline_timeout");
				if((string)session["phase"]!="battle")
					return;
			}
			continue;
		}
		participant["disconnected_at"] = 0;
		if((string)participant["duel_id"]=="" &&
		   search((array)session["queue"],user_id)==-1 &&
		   now-(int)participant["last_action"]>=
		   (int)config["force_match_seconds"])
			session["queue"] += ({user_id});
	}
	match_tianheng_queue(session);
	if(now-(int)session["last_checkpoint"]>=15){
		session["last_checkpoint"] = now;
		save_event_state();
	}
}

int query_pvp_rank_for_test(int total_players,int alive_after)
{
	if(total_players<2 || alive_after<0 || alive_after>=total_players)
		return 0;
	return alive_after+1;
}
