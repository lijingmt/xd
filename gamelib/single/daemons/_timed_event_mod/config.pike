private mapping(string:mixed) default_timed_event_config()
{
	return ([
		"version":1,
		"timezone_offset_minutes":480,
		"events":([
			"tianheng":([
				"enabled":1,"hour":20,"minute":0,
				"signup_seconds":600,"battle_seconds":1800,
				"minimum_level":30,"minimum_players":2,
				"offline_grace_seconds":60,
				"force_match_seconds":30,
			]),
			"jiuyao":([
				"enabled":1,"hour":21,"minute":0,
				"signup_seconds":600,"battle_seconds":2400,
				"minimum_level":30,"minimum_players":1,
				"offline_grace_seconds":60,
				"seal_seconds":120,"boss_move_seconds":20,
			]),
		]),
	]);
}

private int valid_event_number(mapping one,string key,int low,int high)
{
	return intp(one[key]) && (int)one[key]>=low && (int)one[key]<=high;
}

private int valid_one_event_config(mapping one,string event_id)
{
	if(!mappingp(one) || !valid_event_number(one,"enabled",0,1) ||
	   !valid_event_number(one,"hour",0,23) ||
	   !valid_event_number(one,"minute",0,59) ||
	   !valid_event_number(one,"signup_seconds",60,3600) ||
	   !valid_event_number(one,"battle_seconds",300,7200) ||
	   !valid_event_number(one,"minimum_level",1,1000) ||
	   !valid_event_number(one,"minimum_players",1,200) ||
	   !valid_event_number(one,"offline_grace_seconds",15,600))
		return 0;
	if(event_id==EVENT_TIANHENG)
		return valid_event_number(one,"force_match_seconds",10,300);
	if(event_id==EVENT_JIUYAO)
		return valid_event_number(one,"seal_seconds",30,600) &&
			valid_event_number(one,"boss_move_seconds",5,120);
	return 0;
}

private int valid_timed_event_config(mapping candidate)
{
	mapping events;
	if(!mappingp(candidate) || (int)candidate["version"]!=1 ||
	   !valid_event_number(candidate,"timezone_offset_minutes",-720,840) ||
	   !mappingp(candidate["events"]))
		return 0;
	events = candidate["events"];
	return valid_one_event_config(events[EVENT_TIANHENG],EVENT_TIANHENG) &&
		valid_one_event_config(events[EVENT_JIUYAO],EVENT_JIUYAO);
}

int reload_config()
{
	string source;
	mixed decoded = 0;
	mixed err;
	if(Stdio.file_size(TIMED_EVENT_CONFIG_FILE)<=0 ||
	   Stdio.file_size(TIMED_EVENT_CONFIG_FILE)>64*1024){
		timed_event_config = default_timed_event_config();
		werror("[TIMED_EVENTD] 配置不存在或过大，使用安全默认值。\n");
		return 0;
	}
	source = Stdio.read_file(TIMED_EVENT_CONFIG_FILE);
	err = catch{ decoded = Standards.JSON.decode(source); };
	if(err || !mappingp(decoded) ||
	   !valid_timed_event_config((mapping)decoded)){
		timed_event_config = default_timed_event_config();
		werror("[TIMED_EVENTD] 配置校验失败，使用安全默认值。\n");
		return 0;
	}
	timed_event_config = copy_value(decoded);
	config_loaded_mtime = config_file_mtime();
	return 1;
}

private int config_file_mtime()
{
	mixed fs = file_stat(TIMED_EVENT_CONFIG_FILE);
	return objectp(fs) ? (int)fs->mtime : 0;
}

/* 活动时间热调整：调度tick检查配置mtime，变化即重载（校验失败
 * 保留旧配置而不是回默认，避免误写坏文件打乱在线场次）。
 * owner与普通worker都要执行：页面时间窗与集结判定用的是本进程
 * 的配置副本。 */
int maybe_reload_config()
{
	int mtime = config_file_mtime();
	if(mtime<=0 || mtime==config_loaded_mtime)
		return 0;
	int previous_mtime = config_loaded_mtime;
	if(!reload_config()){
		/* 重载失败：回退成默认值是reload_config的行为，此处恢复
		 * 旧mtime避免每tick重试刷屏；配置下次变化再试。 */
		config_loaded_mtime = previous_mtime;
		return 0;
	}
	werror("[TIMED_EVENTD] 配置已热重载。\n");
	return 1;
}

mapping(string:mixed) query_event_config(string event_id)
{
	mapping events = timed_event_config["events"];
	if(!mappingp(events) || !mappingp(events[event_id]))
		return ([]);
	return copy_value(events[event_id]);
}

string query_event_name(string event_id)
{
	if(event_id==EVENT_TIANHENG)
		return "天衡绝境";
	if(event_id==EVENT_JIUYAO)
		return "九曜镇渊";
	return "未知玩法";
}

string query_timed_day_key(void|int at_time)
{
	mapping now_time;
	int offset = (int)timed_event_config["timezone_offset_minutes"];
	if(!at_time)
		at_time = time();
	now_time = gmtime(at_time+offset*60);
	return sprintf("%04d-%02d-%02d",(int)now_time["year"]+1900,
		(int)now_time["mon"]+1,(int)now_time["mday"]);
}

mapping(string:mixed) query_event_window(string event_id,void|int at_time)
{
	mapping one = query_event_config(event_id);
	mapping now_time;
	int offset;
	int current_seconds;
	int start_seconds;
	int signup_end;
	int battle_end;
	int day_start;
	string phase = "closed";
	if(!at_time)
		at_time = time();
	if(!sizeof(one) || !(int)one["enabled"])
		return (["event_id":event_id,"phase":"disabled",
			"date":query_timed_day_key(at_time)]);
	offset = (int)timed_event_config["timezone_offset_minutes"];
	now_time = gmtime(at_time+offset*60);
	current_seconds = (int)now_time["hour"]*3600+
		(int)now_time["min"]*60+(int)now_time["sec"];
	start_seconds = (int)one["hour"]*3600+(int)one["minute"]*60;
	day_start = at_time-current_seconds;
	signup_end = day_start+start_seconds+(int)one["signup_seconds"];
	battle_end = signup_end+(int)one["battle_seconds"];
	if(at_time>=day_start+start_seconds && at_time<signup_end)
		phase = "signup";
	else if(at_time>=signup_end && at_time<battle_end)
		phase = "battle";
	return ([
		"event_id":event_id,
		"name":query_event_name(event_id),
		"date":query_timed_day_key(at_time),
		"phase":phase,
		"start_at":day_start+start_seconds,
		"signup_end_at":signup_end,
		"battle_end_at":battle_end,
		"remaining":phase=="signup" ? signup_end-at_time :
			(phase=="battle" ? battle_end-at_time : 0),
	]);
}

mapping(string:mixed) query_schedule_for_test(string event_id,int at_time)
{
	return query_event_window(event_id,at_time);
}
