private string format_event_duration(int seconds)
{
	if(seconds<0)
		seconds = 0;
	return sprintf("%02d:%02d",seconds/60,seconds%60);
}

private string jiuyao_node_name(string node)
{
	array(string) names = ({"玄枢台","星槎径","青阙门",
		"金衡道","九曜心","赤轮道","沧渊门","月隐径","天纪台"});
	int index = (int)node;
	if(index>=0 && index<sizeof(names))
		return names[index];
	return "未知阵位";
}

string query_room_event_desc(object player,string session_key,string node)
{
	mapping session = sessions[session_key];
	mapping participant;
	string out = "";
	if(!player || !mappingp(session))
		return "活动状态暂不可用。\n";
	participant = session["participants"][player->query_name()];
	if(!mappingp(participant))
		return "你不属于此活动场次。\n";
	out += "活动："+query_event_name((string)session["event_id"])+
		"　阶段："+(string)session["phase"]+"\n";
	if((string)session["event_id"]==EVENT_TIANHENG){
		out += "存活："+(string)count_alive(session)+"人　你的战势："+
			stance_name((string)participant["stance"])+
			"　胜场："+(string)participant["wins"]+"\n";
		if(search(node,"duel_")==0){
			mapping duel = session["duels"][node];
			if(mappingp(duel)){
				string opponent_id = (string)duel["first"]==player->query_name() ?
					(string)duel["second"] : (string)duel["first"];
				mapping opponent = session["participants"][opponent_id];
				if(mappingp(opponent))
					out += "本镜域对手："+(string)opponent["name_cn"]+"\n";
			}
		}
	}
	else{
		int sealed = (int)session["sealed_until"][node]-time();
		out += "存活："+(string)count_alive(session)+"人　巡渊主方位："+
			jiuyao_node_name((string)session["boss_node"])+"\n";
		out += "已完成封脉："+(string)session["seal_count"]+
			"　已击败渊将："+(string)session["general_kills"]+"/4\n";
		if(sealed>0)
			out += "本阵位仍封闭"+format_event_duration(sealed)+"。\n";
	}
	return out;
}

string query_room_event_links(object player,string session_key,string node)
{
	mapping session = sessions[session_key];
	mapping participant;
	string out = "";
	if(!player || !mappingp(session))
		return "[返回活动页:timed_event]\n";
	participant = session["participants"][player->query_name()];
	if(!mappingp(participant))
		return "[返回活动页:timed_event]\n";
	if((string)session["phase"]=="signup"){
		if((string)session["event_id"]==EVENT_TIANHENG)
			out += "[锋势:timed_event stance feng]|[守势:timed_event stance shou]|[变势:timed_event stance bian]\n";
		out += "[查看规则:timed_event]|[退出报名:timed_event leave]\n";
		return out;
	}
	if((string)session["phase"]!="battle")
		return "[返回活动页:timed_event]\n";
	if((string)session["event_id"]==EVENT_TIANHENG){
		if(node=="stage")
			out += "[踏入北衡门:timed_event move north]|[踏入东衡门:timed_event move east]\n"+
				"[踏入南衡门:timed_event move south]|[踏入西衡门:timed_event move west]\n";
		out += "[查看排名:timed_event rank]|[认输退出:timed_event leave]\n";
		return out;
	}
	int index = (int)node;
	if(index>=3) out += "[循脉向北:timed_event move north] ";
	if(index%3<2) out += "[循脉向东:timed_event move east] ";
	if(index<=5) out += "[循脉向南:timed_event move south] ";
	if(index%3>0) out += "[循脉向西:timed_event move west] ";
	out += "\n[协力封脉:timed_event seal]|[查看进度:timed_event rank]|[撤离:timed_event leave]\n";
	return out;
}

private string query_tianheng_rank_text(mapping session)
{
	string out = "【天衡绝境战况】\n";
	array(string) alive = query_alive_ids(session);
	foreach(alive,string user_id){
		mapping participant = session["participants"][user_id];
		out += "存活　"+(string)participant["name_cn"]+"　胜"+
			(string)participant["wins"]+"场\n";
	}
	array eliminated = session["elimination_order"];
	for(int i=sizeof(eliminated)-1;i>=0;i--){
		mapping participant = session["participants"][eliminated[i]];
		if(mappingp(participant))
			out += "第"+(string)participant["rank"]+"名　"+
				(string)participant["name_cn"]+"\n";
	}
	return out;
}

private string query_event_page(object player)
{
	string out = "【每日限时玩法】\n";
	mapping active = query_session_for_user_id(player->query_name(),1);
	mapping player_state = normalize_player_event_state(player);
	out += "天衡令："+(string)player_state["tianheng_tokens"]+
		"　九曜令："+(string)player_state["jiuyao_tokens"]+"\n\n";
	string badges = query_event_badges(player_state);
	if(badges!="")
		out += "活动徽记："+badges+"\n\n";
	foreach(({EVENT_TIANHENG,EVENT_JIUYAO}),string event_id){
		mapping config = query_event_config(event_id);
		mapping window = query_event_window(event_id,time());
		out += "【"+query_event_name(event_id)+"】每日北京时间"+
			sprintf("%02d:%02d",(int)config["hour"],(int)config["minute"])+
			"开放，集结"+(string)((int)config["signup_seconds"]/60)+"分钟。\n";
		if((string)window["phase"]=="signup")
			out += "正在集结，剩余"+format_event_duration((int)window["remaining"])+
				" [立即进入:timed_event join "+event_id+"]\n";
		else if((string)window["phase"]=="battle")
			out += "本场已经开战，不能中途加入。\n";
		else
			out += "当前未开放。\n";
		if(event_id==EVENT_TIANHENG)
			out += "随机镜域1v1；移动触发配对；锋、守、变三势只产生小幅局内差异；一次落败即结算。\n";
		else
			out += "九宫追猎巡渊主；封闭曜脉改变其路线；四名渊将按战局阶段降临。\n";
		out += "\n";
	}
	if(active)
		out += "你已在"+query_event_name((string)active["event_id"])+
			"中。[返回活动场地:timed_event return]\n";
	out += "所有奖励均为游戏内经验、金币和玩法令牌；VIP不增加战斗数值或入场次数。\n";
	out += "[令牌兑换商店:timed_event shop]\n";
	out += "[返回:look]\n";
	return out;
}

mapping(string:mixed) query_player_status(object player)
{
	mapping result = (["active":0,"phase":"closed","popup_id":""]);
	mapping active;
	if(!player)
		return result;
	active = query_session_for_user_id(player->query_name(),1);
	if(active){
		result["active"] = 1;
		result["joined"] = 1;
		result["event_id"] = active["event_id"];
		result["name"] = query_event_name((string)active["event_id"]);
		result["phase"] = active["phase"];
		result["remaining"] = (string)active["phase"]=="signup" ?
			(int)active["battle_start_at"]-time() :
			(int)active["battle_end_at"]-time();
		result["command"] = "timed_event return";
		return result;
	}
	foreach(({EVENT_TIANHENG,EVENT_JIUYAO}),string event_id){
		mapping window = query_event_window(event_id,time());
		mapping config = query_event_config(event_id);
		if((string)window["phase"]!="signup")
			continue;
		result["active"] = 1;
		result["joined"] = 0;
		result["event_id"] = event_id;
		result["name"] = query_event_name(event_id);
		result["phase"] = "signup";
		result["remaining"] = window["remaining"];
		result["eligible"] = player->query_level()>=(int)config["minimum_level"] &&
			!player_already_entered(player,event_id,(string)window["date"]);
		result["command"] = "timed_event join "+event_id;
		result["popup_id"] = event_id+"|"+(string)window["date"];
		break;
	}
	return result;
}
