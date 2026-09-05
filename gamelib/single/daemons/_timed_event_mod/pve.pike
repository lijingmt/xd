array(string) query_jiuyao_adjacent_nodes(string node)
{
	int index = (int)node;
	int row;
	int column;
	array(string) result = ({});
	if(index<0 || index>8)
		return result;
	row = index/3;
	column = index%3;
	if(row>0) result += ({(string)(index-3)});
	if(column<2) result += ({(string)(index+1)});
	if(row<2) result += ({(string)(index+3)});
	if(column>0) result += ({(string)(index-1)});
	return result;
}

array(string) query_adjacent_nodes_for_test(string node)
{
	return query_jiuyao_adjacent_nodes(node);
}

int query_seal_requirement_for_test(int alive_players)
{
	return alive_players>=4 ? 2 : 1;
}

private object|zero query_jiuyao_npc(mapping session,string role)
{
	array npcs = runtime_npcs[query_session_key(session)];
	if(!arrayp(npcs))
		return 0;
	foreach(npcs,object npc)
		if(npc && functionp(npc->query_timed_event_role) &&
		   npc->query_timed_event_role()==role)
			return npc;
	return 0;
}

private int query_jiuyao_average_level(mapping session)
{
	int total = 0;
	int count = 0;
	foreach(indices((mapping)session["participants"]),string user_id){
		object player = find_player(user_id);
		if(player){
			total += player->query_level();
			count++;
		}
	}
	if(!count)
		return 30;
	return total/count;
}

private object spawn_jiuyao_npc(mapping session,string role,string node,
	string display_name,int boss_flag,int life_scale)
{
	string session_key = query_session_key(session);
	array npcs = runtime_npcs[session_key];
	object npc;
	object room;
	int level = query_jiuyao_average_level(session);
	int total_life = 0;
	int total_power = 0;
	int player_count = 0;
	int desired_life;
	int desired_power;
	if(!arrayp(npcs))
		npcs = ({});
	foreach(indices((mapping)session["participants"]),string user_id){
		object player = find_player(user_id);
		if(player && (int)session["participants"][user_id]["alive"]){
			int one_power = player->query_str();
			if(player->query_think()>one_power)
				one_power = player->query_think();
			total_life += player->query_life_max();
			total_power += one_power;
			player_count++;
		}
	}
	if(player_count<1)
		player_count = 1;
	if(boss_flag){
		desired_life = total_life*3;
		desired_power = total_power/player_count/2;
	}
	else{
		desired_life = total_life/player_count*2;
		desired_power = total_power/player_count/3;
	}
	if(life_scale>1)
		desired_life = desired_life*life_scale/(player_count+1);
	npc = clone(ROOT+"/gamelib/clone/npc/timed_event/yuanling.pike");
	npc->configure_timed_event_npc(session_key,role,display_name,level,
		boss_flag,desired_life,desired_power);
	room = ensure_event_room(session,node,"pve_node");
	npc->move(room);
	npcs += ({npc});
	runtime_npcs[session_key] = npcs;
	return npc;
}

private void notify_session_players(mapping session,string message)
{
	foreach(indices((mapping)session["participants"]),string user_id){
		object player = find_player(user_id);
		if(player && (int)session["participants"][user_id]["alive"])
			tell_object(player,message);
	}
}

private void finish_jiuyao(mapping session,string result,string reason)
{
	foreach(indices((mapping)session["participants"]),string user_id){
		mapping participant = session["participants"][user_id];
		object player = find_player(user_id);
		if(!mappingp(participant["reward"]))
			prepare_participant_reward(session,user_id,
				(int)participant["alive"] ? result : "participation",0);
		if(player){
			/* 单人回迁失败不中断结算循环（同pvp：防全员滞留死房）。 */
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
	session["result"] = result;
	destroy_session_runtime(session);
	save_event_state();
}

private void eliminate_jiuyao(mapping session,string user_id,string reason)
{
	mapping participant = session["participants"][user_id];
	object player = find_player(user_id);
	if(!mappingp(participant) || !(int)participant["alive"])
		return;
	participant["alive"] = 0;
	participant["eliminated_at"] = time();
	participant["eliminate_reason"] = reason;
	session["elimination_order"] += ({user_id});
	prepare_participant_reward(session,user_id,"participation",0);
	if(player){
		mixed settle_err = catch {
			clean_event_fight(player);
			return_player_from_event(player,participant);
			claim_participant_reward(session,user_id,player);
		};
		if(settle_err)
			werror("[TIMED_EVENT_SETTLE] user=%s error=%s\n",
				user_id,describe_error(settle_err)[..180]);
		tell_object(player,"你已被渊息送离九曜镇渊，今日不能再次入场。\n");
	}
	if(count_alive(session)<=0)
		finish_jiuyao(session,"failure","all_players_defeated");
	else
		save_event_state();
}

private int move_jiuyao_player(mapping session,object player,string direction)
{
	mapping participant = session["participants"][player->query_name()];
	string current;
	int index;
	int target = -1;
	if(!mappingp(participant) || !(int)participant["alive"] ||
	   player->query_in_combat())
		return 0;
	current = (string)participant["room_node"];
	index = (int)current;
	if(direction=="north" && index>=3) target = index-3;
	else if(direction=="east" && index%3<2) target = index+1;
	else if(direction=="south" && index<=5) target = index+3;
	else if(direction=="west" && index%3>0) target = index-1;
	if(target<0 || target>8)
		return 0;
	participant["room_node"] = (string)target;
	participant["last_action"] = time();
	if(!internal_move_player(player,
	   ensure_event_room(session,(string)target,"pve_node")))
		return 0;
	tell_object(player,"你循着曜脉抵达新的阵位。\n");
	save_event_state();
	return 1;
}

private int seal_jiuyao_node(mapping session,object player)
{
	mapping participant = session["participants"][player->query_name()];
	string node;
	mapping helpers;
	int requirement;
	int seal_seconds;
	object boss;
	int damage;
	if(!mappingp(participant) || !(int)participant["alive"] ||
	   player->query_in_combat())
		return 0;
	node = (string)participant["room_node"];
	if((int)session["sealed_until"][node]>time()){
		tell_object(player,"此处曜脉仍在封闭中。\n");
		return 1;
	}
	helpers = session["seal_helpers"][node];
	if(!mappingp(helpers))
		helpers = ([]);
	if((int)helpers[player->query_name()]){
		tell_object(player,"你已经为本次封脉注入过灵力，等待其他同伴响应。\n");
		return 1;
	}
	helpers[player->query_name()] = 1;
	session["seal_helpers"][node] = helpers;
	requirement = query_seal_requirement_for_test(count_alive(session));
	if(sizeof(helpers)<requirement){
		tell_object(player,"封脉已完成"+(string)sizeof(helpers)+"/"+
			(string)requirement+"，还需一名同伴响应。\n");
		save_event_state();
		return 1;
	}
	seal_seconds = (int)query_event_config(EVENT_JIUYAO)["seal_seconds"];
	session["sealed_until"][node] = time()+seal_seconds;
	session["seal_helpers"][node] = ([]);
	session["seal_count"] = (int)session["seal_count"]+1;
	boss = query_jiuyao_npc(session,"boss");
	if(boss){
		damage = boss->query_life_max()*2/100;
		if(boss->get_cur_life()-damage<1)
			damage = boss->get_cur_life()-1;
		if(damage>0)
			boss->set_life(boss->get_cur_life()-damage);
	}
	notify_session_players(session,"【曜脉封成】一处阵位被封闭"+
		(string)seal_seconds+"秒，渊主受到2%气血上限的阵纹反噬。\n");
	save_event_state();
	return 1;
}

private int engage_jiuyao_npc(mapping session,object player,object npc)
{
	mapping participant = session["participants"][player->query_name()];
	if(!mappingp(participant) || !(int)participant["alive"] || !npc ||
	   environment(player)!=environment(npc) ||
	   !functionp(npc->query_timed_event_session) ||
	   npc->query_timed_event_session()!=query_session_key(session))
		return 0;
	if(player->query_in_combat())
		return 0;
	player->kill(npc,0);
	if(!npc->query_in_combat())
		npc->_fight(player);
	return 1;
}

int can_engage_event_npc(object player,object npc)
{
	mapping session;
	if(!player || !npc || !functionp(npc->query_timed_event_session))
		return 0;
	session = sessions[(string)npc->query_timed_event_session()];
	if(!mappingp(session) || (string)session["event_id"]!=EVENT_JIUYAO ||
	   (string)session["phase"]!="battle")
		return 0;
	return mappingp(session["participants"][player->query_name()]) &&
		(int)session["participants"][player->query_name()]["alive"];
}

int handle_event_npc_death(object npc,object|zero killer)
{
	string session_key;
	string role;
	mapping session;
	array npcs;
	if(!npc || !functionp(npc->is_timed_event_npc) ||
	   !npc->is_timed_event_npc())
		return 0;
	session_key = npc->query_timed_event_session();
	role = npc->query_timed_event_role();
	session = sessions[session_key];
	if(!mappingp(session) || (string)session["phase"]!="battle")
		return 0;
	npc->_clean_fight();
	npcs = runtime_npcs[session_key];
	if(arrayp(npcs))
		runtime_npcs[session_key] = npcs-({npc});
	if(role=="boss"){
		session["boss_alive"] = 0;
		notify_session_players(session,"【九曜镇渊】巡渊主的核心被曜印封碎，镇渊成功！\n");
		destruct(npc);
		finish_jiuyao(session,"victory","boss_defeated");
		return 1;
	}
	session["general_kills"] = (int)session["general_kills"]+1;
	notify_session_players(session,"【渊将伏诛】"+npc->query_name_cn()+
		"被击败，全队镇渊积分+1。\n");
	destruct(npc);
	save_event_state();
	return 1;
}

private void move_jiuyao_npc(mapping session,object npc,string current_node)
{
	array(string) adjacent = query_jiuyao_adjacent_nodes(current_node);
	array(string) available = ({});
	foreach(adjacent,string node)
		if((int)session["sealed_until"][node]<=time())
			available += ({node});
	if(!sizeof(available)){
		if(npc->query_timed_event_role()=="boss"){
			int damage = npc->query_life_max()/100;
			if(npc->get_cur_life()-damage<=0)
				handle_event_npc_death(npc,0);
			else
				npc->set_life(npc->get_cur_life()-damage);
		}
		return;
	}
	string target_node = available[random(sizeof(available))];
	npc->move(ensure_event_room(session,target_node,"pve_node"));
	if(npc->query_timed_event_role()=="boss")
		session["boss_node"] = target_node;
}

private void start_jiuyao_npc_fight(mapping session,object npc)
{
	object env;
	array(object) candidates = ({});
	if(!npc || npc->query_in_combat())
		return;
	env = environment(npc);
	foreach(all_inventory(env),object one)
		if(one && one->is && one->is("player") &&
		   mappingp(session["participants"][one->query_name()]) &&
		   (int)session["participants"][one->query_name()]["alive"])
			candidates += ({one});
	if(!sizeof(candidates))
		return;
	object target = candidates[random(sizeof(candidates))];
	npc->_fight(target);
	if(!target->query_in_combat())
		target->_fight(npc);
	tell_object(target,npc->query_name_cn()+"循着渊息主动向你袭来！\n");
}

private void spawn_due_jiuyao_generals(mapping session,int now)
{
	array(string) names = ({"沉山渊将","燎空渊将","断潮渊将","蚀月渊将"});
	array(string) nodes = ({"8","2","6","4"});
	int duration = (int)session["battle_end_at"]-
		(int)session["battle_start_at"];
	int elapsed = now-(int)session["battle_start_at"];
	for(int i=0;i<4;i++){
		string role = "general_"+(string)(i+1);
		if(search((array)session["generals_spawned"],role)!=-1)
			continue;
		if(elapsed<duration*(i+1)/5)
			continue;
		session["generals_spawned"] += ({role});
		spawn_jiuyao_npc(session,role,nodes[i],names[i],0,
			count_alive(session)+1);
		notify_session_players(session,"【渊门震动】"+names[i]+
			"已在九曜阵中现身。\n");
	}
}

private void start_jiuyao(mapping session)
{
	mapping config = query_event_config(EVENT_JIUYAO);
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
				tell_object(player,"九曜镇渊集结人数不足，本场取消且不消耗今日资格。\n");
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
		participant["room_node"] = "4";
		participant["last_action"] = time();
		mark_player_entry(player,EVENT_JIUYAO,(string)session["date"]);
		player->set_life(player->query_life_max());
		player->set_mofa(player->query_mofa_max());
		internal_move_player(player,
			ensure_event_room(session,"4","pve_node"));
		tell_object(player,"【九曜镇渊】你从九曜心出发。追踪巡渊主、封闭曜脉，并提防阶段渊将。\n");
	}
	spawn_jiuyao_npc(session,"boss","0","巡渊主",1,
		2+sizeof(accepted)*2);
	session["boss_alive"] = 1;
	session["boss_spawned"] = 1;
	session["boss_node"] = "0";
	session["last_boss_move"] = time();
	save_event_state();
}

private void tick_jiuyao(mapping session,int now)
{
	mapping config = query_event_config(EVENT_JIUYAO);
	array(string) alive_ids = query_alive_ids(session);
	object boss;
	array npcs;
	foreach(alive_ids,string user_id){
		mapping participant = session["participants"][user_id];
		object player = find_player(user_id);
		if(LOGICALZONED->query_user_group(user_id)!=(string)session["group"]){
			eliminate_jiuyao(session,user_id,"logical_zone_changed");
			if((string)session["phase"]!="battle")
				return;
			continue;
		}
		if(!player){
			if(!(int)participant["disconnected_at"])
				participant["disconnected_at"] = now;
			else if(now-(int)participant["disconnected_at"]>=
			   (int)config["offline_grace_seconds"]){
				eliminate_jiuyao(session,user_id,"offline_timeout");
				if((string)session["phase"]!="battle")
					return;
			}
		}
		else
			participant["disconnected_at"] = 0;
	}
	spawn_due_jiuyao_generals(session,now);
	boss = query_jiuyao_npc(session,"boss");
	if(!boss && (int)session["boss_alive"]){
		boss = spawn_jiuyao_npc(session,"boss",
			(string)session["boss_node"],"巡渊主",1,
			2+count_alive(session)*2);
	}
	if(boss){
		start_jiuyao_npc_fight(session,boss);
		if(!boss->query_in_combat() && now-(int)session["last_boss_move"]>=
		   (int)config["boss_move_seconds"]){
			move_jiuyao_npc(session,boss,(string)session["boss_node"]);
			session["last_boss_move"] = now;
		}
	}
	npcs = runtime_npcs[query_session_key(session)];
	if(arrayp(npcs))
		foreach(npcs,object npc)
			if(npc && npc!=boss)
				start_jiuyao_npc_fight(session,npc);
	if(now-(int)session["last_checkpoint"]>=15){
		session["last_checkpoint"] = now;
		save_event_state();
	}
}
