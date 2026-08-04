private mapping create_participant(object player)
{
	return ([
		"name":player->query_name(),
		"name_cn":player->query_name_cn(1),
		"level":player->query_level(),
		"joined_at":time(),
		"alive":1,
		"stance":"bian",
		"return_path":safe_return_path(player),
		"room_node":"lobby",
		"duel_id":"",
		"wins":0,
		"rank":0,
		"last_action":time(),
		"disconnected_at":0,
		"eliminated_at":0,
		"eliminate_reason":"",
		"reward_claimed":0,
	]);
}

private string join_event(object player,string event_id)
{
	mapping config;
	mapping window;
	mapping session;
	mapping existing;
	string group;
	object room;
	object autofightd;
	if(event_id!=EVENT_TIANHENG && event_id!=EVENT_JIUYAO)
		return "未找到该限时玩法。\n[返回:timed_event]\n";
	config = query_event_config(event_id);
	window = query_event_window(event_id,time());
	if((string)window["phase"]!="signup")
		return "当前不在集结时段，战斗开始后不能中途加入。\n[返回:timed_event]\n";
	if(player->query_level()<(int)config["minimum_level"])
		return "需要达到"+(string)config["minimum_level"]+"级才能参加。\n[返回:timed_event]\n";
	if(player->query_in_combat())
		return "请先结束当前战斗再进入。\n[返回:look]\n";
	existing = query_session_for_user_id(player->query_name(),1);
	if(existing){
		restore_player(player);
		player->command("look");
		return "";
	}
	if(player_already_entered(player,event_id,(string)window["date"]))
		return "你今天已经参加过本玩法，明日可再次挑战。\n[返回:timed_event]\n";
	group = LOGICALZONED->query_user_group(player->query_name());
	session = ensure_session(event_id,group,window);
	if((string)session["phase"]!="signup")
		return "本逻辑区的活动已经开战，不能中途加入。\n[返回:timed_event]\n";
	session["participants"][player->query_name()] = create_participant(player);
	autofightd = (object)(ROOT+"/gamelib/single/daemons/autofightd.pike");
	if(autofightd)
		autofightd->stop_autofight(player);
	room = ensure_event_room(session,"lobby",
		event_id==EVENT_TIANHENG ? "pvp_lobby" : "pve_lobby");
	if(!internal_move_player(player,room)){
		m_delete(session["participants"],player->query_name());
		save_event_state();
		return "进入活动场地失败，请稍后再试。\n[返回:look]\n";
	}
	save_event_state();
	player->command("look");
	return "";
}

private string leave_event(object player,mapping session)
{
	mapping participant = session["participants"][player->query_name()];
	if(!mappingp(participant))
		return "你不在本场活动中。\n[返回:timed_event]\n";
	if((string)session["phase"]=="signup"){
		m_delete(session["participants"],player->query_name());
		return_player_from_event(player,participant);
		save_event_state();
		player->command("look");
		return "";
	}
	if((string)session["phase"]!="battle")
		return "本场已经结算。\n[返回:timed_event]\n";
	if((string)session["event_id"]==EVENT_TIANHENG)
		eliminate_tianheng(session,player->query_name(),0,"surrender");
	else
		eliminate_jiuyao(session,player->query_name(),"withdraw");
	player->command("look");
	return "";
}

string handle_command(object player,string action,string value)
{
	mapping session;
	mapping participant;
	if(!player)
		return "";
	claim_all_pending(player);
	if(!action || action=="")
		return query_event_page(player);
	if(action=="shop")
		return query_event_shop_page(player);
	if(action=="confirm")
		return query_event_shop_confirm_page(player,value);
	if(action=="exchange")
		return exchange_event_shop_item(player,value);
	if(action=="join")
		return join_event(player,value);
	session = query_session_for_user_id(player->query_name(),1);
	if(action=="return"){
		if(!session || !restore_player(player))
			return "当前没有可返回的活动场次。\n[返回:timed_event]\n";
		player->command("look");
		return "";
	}
	if(!session)
		return "你当前没有参加活动。\n[返回:timed_event]\n";
	participant = session["participants"][player->query_name()];
	if(action=="leave")
		return leave_event(player,session);
	if(action=="stance"){
		if((string)session["event_id"]!=EVENT_TIANHENG ||
		   (string)session["phase"]!="signup")
			return "战势只能在天衡绝境开战前选择。\n[返回:look]\n";
		if(search(({"feng","shou","bian"}),value)==-1)
			return "未知战势。\n[返回:look]\n";
		participant["stance"] = value;
		save_event_state();
		return "你选择了"+stance_name(value)+"。\n[返回:look]\n";
	}
	if(action=="move"){
		int moved = (string)session["event_id"]==EVENT_TIANHENG ?
			queue_tianheng_move(session,player,value) :
			move_jiuyao_player(session,player,value);
		if(!moved)
			return "现在无法向该方向行动，请检查边界或先结束战斗。\n[返回:look]\n";
		player->command("look");
		return "";
	}
	if(action=="seal"){
		if((string)session["event_id"]!=EVENT_JIUYAO ||
		   (string)session["phase"]!="battle")
			return "当前不能封脉。\n[返回:look]\n";
		seal_jiuyao_node(session,player);
		player->command("look");
		return "";
	}
	if(action=="engage"){
		object npc = present(value,environment(player));
		if(!npc || !engage_jiuyao_npc(session,player,npc))
			return "目标已经离开，或你当前不能迎战。\n[返回:look]\n";
		player->command("look");
		return "";
	}
	if(action=="rank"){
		if((string)session["event_id"]==EVENT_TIANHENG)
			return query_tianheng_rank_text(session)+"[返回:look]\n";
		return "【九曜镇渊进度】存活"+(string)count_alive(session)+
			"人，封脉"+(string)session["seal_count"]+"次，击败渊将"+
			(string)session["general_kills"]+"/4。\n[返回:look]\n";
	}
	return query_event_page(player);
}

int handle_player_defeat(object player,object|zero killer)
{
	mapping session;
	if(!player)
		return 0;
	session = query_session_for_user_id(player->query_name(),1);
	if(!session || (string)session["phase"]!="battle" ||
	   !is_event_room(environment(player)))
		return 0;
	if((string)session["event_id"]==EVENT_TIANHENG)
		eliminate_tianheng(session,player->query_name(),killer,"defeated");
	else
		eliminate_jiuyao(session,player->query_name(),"defeated");
	return 1;
}

int block_event_escape(object player)
{
	mapping session;
	if(!player || !is_event_room(environment(player)))
		return 0;
	session = query_session_for_user_id(player->query_name(),1);
	if(!session || (string)session["phase"]!="battle")
		return 0;
	player->set_action("attack");
	tell_object(player,"限时秘境不能使用普通逃跑；请继续迎战，或使用活动场景中的认输／撤离按钮完成结算。\n");
	return 1;
}

private void announce_signup(string event_id,mapping window)
{
	string popup_id = event_id+"|"+(string)window["date"];
	if((int)announced_signup[popup_id])
		return;
	announced_signup[popup_id] = 1;
	foreach(users(),object player)
		if(player && player->is && player->is("player"))
			tell_object(player,"【限时通道】"+query_event_name(event_id)+
				"开始集结，十分钟后开战。[查看并进入:timed_event]\n");
}

private void prune_old_sessions(int now)
{
	foreach(indices(sessions),string session_key){
		mapping session = sessions[session_key];
		int all_claimed = 1;
		if((string)session["phase"]=="signup" ||
		   (string)session["phase"]=="battle")
			continue;
		if(now-(int)session["finished_at"]<14*86400)
			continue;
		foreach(values((mapping)session["participants"]),mapping participant)
			if(mappingp(participant["reward"]) &&
			   !(int)participant["reward_claimed"])
				all_claimed = 0;
		if(all_claimed)
			m_delete(sessions,session_key);
	}
}

private void tick_sessions()
{
	int now = time();
	foreach(({EVENT_TIANHENG,EVENT_JIUYAO}),string event_id){
		mapping window = query_event_window(event_id,now);
		if((string)window["phase"]=="signup")
			announce_signup(event_id,window);
	}
	foreach(indices(sessions),string session_key){
		mapping session = sessions[session_key];
		string phase = (string)session["phase"];
		if(phase=="signup" && now>=(int)session["battle_start_at"] &&
		   now<(int)session["battle_end_at"]){
			if((string)session["event_id"]==EVENT_TIANHENG)
				start_tianheng(session);
			else
				start_jiuyao(session);
			continue;
		}
		if(phase=="signup" && now>=(int)session["battle_end_at"]){
			session["phase"] = "cancelled";
			session["finished_at"] = now;
			session["finish_reason"] = "window_expired";
			destroy_session_runtime(session);
			save_event_state();
			continue;
		}
		if(phase!="battle")
			continue;
		if(now>=(int)session["battle_end_at"]){
			if((string)session["event_id"]==EVENT_TIANHENG)
				finish_tianheng(session,"time_limit");
			else
				finish_jiuyao(session,"failure","time_limit");
			continue;
		}
		if((string)session["event_id"]==EVENT_TIANHENG)
			tick_tianheng(session,now);
		else
			tick_jiuyao(session,now);
	}
	prune_old_sessions(now);
	call_out(tick_sessions,TIMED_EVENT_TICK_SECONDS);
}

private int is_timed_event_test_caller()
{
	object caller = previous_object();
	string caller_path = caller ? file_name(caller) : "";
	return caller_path!="" &&
		has_prefix(caller_path,ROOT+"/test_unit/test_timed_event_system");
}

/** 仅供指定 TestUnit 对象创建即时场次；普通命令和管理脚本无权调用。 */
string begin_session_for_test(string event_id,array(object) players)
{
	string date;
	string group;
	mapping window;
	mapping session;
	if(!is_timed_event_test_caller() || !sizeof(players) ||
	   (event_id!=EVENT_TIANHENG && event_id!=EVENT_JIUYAO))
		return "";
	date = "testunit-"+(string)time()+"-"+(string)random(1000000);
	group = LOGICALZONED->query_user_group(players[0]->query_name());
	window = (["date":date,"signup_end_at":time(),
		"battle_end_at":time()+600]);
	session = ensure_session(event_id,group,window);
	foreach(players,object player)
		session["participants"][player->query_name()] =
			create_participant(player);
	if(event_id==EVENT_TIANHENG)
		start_tianheng(session);
	else
		start_jiuyao(session);
	return query_session_key(session);
}

int cleanup_session_for_test(string session_key)
{
	mapping session;
	if(!is_timed_event_test_caller())
		return 0;
	session = sessions[session_key];
	if(!mappingp(session))
		return 0;
	destroy_session_runtime(session);
	m_delete(sessions,session_key);
	save_event_state();
	return 1;
}
