private int valid_saved_participant(mapping participant)
{
	return mappingp(participant) && stringp(participant["name"]) &&
		sizeof((string)participant["name"])>0 &&
		intp(participant["joined_at"]) && intp(participant["alive"]) &&
		intp(participant["reward_claimed"]);
}

private int valid_saved_session(mapping session)
{
	mapping participants;
	string event_id;
	string phase;
	if(!mappingp(session) || !stringp(session["event_id"]) ||
	   !stringp(session["date"]) || !stringp(session["group"]) ||
	   !stringp(session["phase"]) ||
	   !mappingp(session["participants"]) ||
	   !arrayp(session["elimination_order"]) ||
	   !intp(session["created_at"]) || !intp(session["battle_start_at"]) ||
	   !intp(session["battle_end_at"]))
		return 0;
	event_id = (string)session["event_id"];
	phase = (string)session["phase"];
	if(event_id!=EVENT_TIANHENG && event_id!=EVENT_JIUYAO)
		return 0;
	if(search(({"signup","battle","finished","cancelled"}),phase)==-1)
		return 0;
	participants = session["participants"];
	if(sizeof(participants)>500)
		return 0;
	foreach(indices(participants),string user_id)
		if(sizeof(user_id)<2 || sizeof(user_id)>64 ||
		   !valid_saved_participant(participants[user_id]))
			return 0;
	return 1;
}

private int valid_saved_event_state(mapping saved)
{
	mapping stored_sessions;
	if(!mappingp(saved) || (int)saved["version"]!=TIMED_EVENT_STATE_VERSION ||
	   !mappingp(saved["sessions"]))
		return 0;
	stored_sessions = saved["sessions"];
	if(sizeof(stored_sessions)>256)
		return 0;
	foreach(indices(stored_sessions),string session_key)
		if(sizeof(session_key)<3 || sizeof(session_key)>256 ||
		   !valid_saved_session(stored_sessions[session_key]))
			return 0;
	return 1;
}

private int save_event_state()
{
	string temp_file = TIMED_EVENT_STATE_FILE+".tmp";
	string backup_temp = TIMED_EVENT_STATE_FILE+".bak.tmp";
	string encoded;
	int live_size;
	int ok = 0;
	mixed err;
	encoded = Standards.JSON.encode(([
		"version":TIMED_EVENT_STATE_VERSION,
		"saved_at":time(),
		"sessions":sessions,
	]));
	mkdir(TIMED_EVENT_STATE_DIR);
	err = catch{
		rm(temp_file);
		rm(backup_temp);
		if(Stdio.write_file(temp_file,encoded)>0 &&
		   Stdio.file_size(temp_file)==sizeof(encoded)){
			live_size = Stdio.file_size(TIMED_EVENT_STATE_FILE);
			if(live_size>0){
				Stdio.cp(TIMED_EVENT_STATE_FILE,backup_temp);
				if(Stdio.file_size(backup_temp)==live_size &&
				   mv(backup_temp,TIMED_EVENT_STATE_FILE+".bak") &&
				   mv(temp_file,TIMED_EVENT_STATE_FILE))
					ok = Stdio.file_size(TIMED_EVENT_STATE_FILE)==sizeof(encoded);
			}
			else if(mv(temp_file,TIMED_EVENT_STATE_FILE))
				ok = Stdio.file_size(TIMED_EVENT_STATE_FILE)==sizeof(encoded);
		}
	};
	if(err)
		werror("[TIMED_EVENTD] 活动状态保存异常: %s\n",describe_error(err));
	if(!ok){
		rm(temp_file);
		rm(backup_temp);
		werror("[TIMED_EVENTD] 活动状态保存失败。\n");
	}
	return ok;
}

private void cancel_interrupted_battles()
{
	int changed = 0;
	foreach(indices(sessions),string session_key){
		mapping session = sessions[session_key];
		if((string)session["phase"]=="battle"){
			session["phase"] = "cancelled";
			session["finished_at"] = time();
			session["finish_reason"] = "server_restart";
			foreach(indices((mapping)session["participants"]),string user_id){
				mapping participant = session["participants"][user_id];
				if(!mappingp(participant["reward"]))
					participant["reward"] = ([
						"exp":0,"money":0,"tokens":1,
						"message":"活动因服务器重启安全中止，补发1枚纪念令。",
					]);
			}
			changed = 1;
		}
		else if((string)session["phase"]=="signup" &&
		   time()>=(int)session["battle_start_at"]){
			// 候场状态没有权威战斗快照；跨过开战点后宁可无损取消，
			// 也不能把登录早晚变成参赛资格差异。
			session["phase"] = "cancelled";
			session["finished_at"] = time();
			session["finish_reason"] = "restart_crossed_start";
			changed = 1;
		}
	}
	if(changed)
		save_event_state();
}

private void load_event_state()
{
	string source;
	mixed decoded = 0;
	mixed err;
	sessions = ([]);
	if(Stdio.file_size(TIMED_EVENT_STATE_FILE)<=0)
		return;
	if(Stdio.file_size(TIMED_EVENT_STATE_FILE)>4*1024*1024){
		werror("[TIMED_EVENTD] 活动状态文件过大，拒绝载入。\n");
		return;
	}
	source = Stdio.read_file(TIMED_EVENT_STATE_FILE);
	err = catch{ decoded = Standards.JSON.decode(source); };
	if(err || !mappingp(decoded) ||
	   !valid_saved_event_state((mapping)decoded)){
		werror("[TIMED_EVENTD] 活动状态损坏，拒绝载入。\n");
		return;
	}
	sessions = copy_value(decoded["sessions"]);
	cancel_interrupted_battles();
}
