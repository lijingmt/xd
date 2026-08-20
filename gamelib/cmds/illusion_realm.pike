#include <command.h>
#include <gamelib/include/gamelib.h>

private string time_text(int value)
{
	if(value<=0)
		return "未确定";
	string text = ctime(value);
	return text[0..sizeof(text)-2];
}

private string chapter_next_label(mapping chapter)
{
	string kind = (string)chapter["target_kind"];
	string name = (string)chapter["target_name"];
	string location = (string)chapter["target_location"];
	if((int)chapter["ready"] || kind=="ready")
		return "领取本章并继续";
	if(kind=="choice")
		return "选择三途命途";
	if(kind=="route")
		return "查看命途终章指引";
	if(location!="")
		return "一键前往"+location+"·"+name;
	return name!="" ? name : "继续本章";
}

private string chapter_next_link(mapping chapter)
{
	return "[▶ 下一步："+chapter_next_label(chapter)+
		":illusion_realm next]\n";
}

private string chapter_claim_link(int chapter_number)
{
	return "[立即领取第"+(string)chapter_number+
		"章并进入下一章:illusion_realm claim "+
		(string)chapter_number+"]\n";
}

private string boss_challenge_link(mapping target)
{
	string kind = (string)(target["target_kind"] || target["action"] || "");
	string display_name = (string)(target["target_name"] ||
		target["name"] || "任务首领");
	string scope = has_index(target,"target_kind") ? "chapter" : "route";
	if(search(({"boss","story_boss","hunt"}),kind)==-1 ||
	   (string)(target["target_combat_name"] ||
		target["combat_name"] || "")=="")
		return "";
	// 不从配置直接拼 kill。先在玩家当前房间枚举真实 NPC，第二步再用
	// 该对象的实际 id 与零起始序号挑战，避免单只首领被误写成第 2 只。
	return "[⚔ 查找并挑战"+display_name+":illusion_realm challenge "+
		scope+"]\n";
}

private int chapter_target_in_current_room(object me,mapping chapter)
{
	object room;
	array(string) target_rooms = ({});
	if(!me || !mappingp(chapter))
		return 0;
	room = environment(me);
	if(arrayp(chapter["target_rooms"]))
		target_rooms = (array(string))chapter["target_rooms"];
	if(!sizeof(target_rooms) && (string)(chapter["target_room"] || "")!="")
		target_rooms = ({(string)chapter["target_room"]});
	if(!room || !sizeof(target_rooms))
		return 0;
	foreach(target_rooms,string target_room)
		if(MAP_WORKERD->static_room_locations_match(
		   file_name(room),target_room))
			return 1;
	return 0;
}

private string chapter_arrival_actions(mapping chapter)
{
	string kind = (string)chapter["target_kind"];
	if(search(({"boss","story_boss"}),kind)!=-1)
		return "\n【下一步】首领已经在当前区域，先确认房间 NPC，再进入正式战斗。\n"+
			boss_challenge_link(chapter)+
			"[返回游戏:look]|[查看本章进度:illusion_realm]\n";
	if(kind=="hunt")
		return "\n【下一步】目标已经在当前区域。\n"+
			"[挂机至本章狩猎完成:illusion_realm hunt]|"+
			"[持续自动挂机:autofight start]\n"+
			"[返回游戏:look]|[查看本章进度:illusion_realm]\n";
	if(kind=="explore")
		return "\n【下一步】已经到达探索地点，请确认本次到访。\n"+
			"[完成当前探索:illusion_realm next]|"+
			"[返回游戏:look]|[查看本章进度:illusion_realm]\n";
	return "";
}

private mapping current_challenge_target(object me,string scope)
{
	mapping progress;
	mapping target;
	array chapters;
	int chapter_number;
	string kind;
	if(scope=="route"){
		target = SEASONALD->query_route_step(me);
		if(!(int)target["ok"] || (int)target["done"] ||
		   (string)target["action"]!="hunt")
			return (["ok":0,
				"message":"当前破阵终章没有可挑战的首领。"]);
		return target+(["ok":1,"target_kind":"route_boss",
			"target_name":(string)target["name"],
			"target_combat_name":(string)target["combat_name"]]);
	}
	progress = SEASONALD->query_player_progress(me);
	if(!(int)progress["ok"])
		return (["ok":0,"message":(string)progress["message"]]);
	chapters = (array)progress["chapters"];
	chapter_number = (int)progress["chapter_claimed"]+1;
	if(chapter_number<1 || chapter_number>sizeof(chapters))
		return (["ok":0,"message":"八十一章已经全部完成。"]);
	target = (mapping)chapters[chapter_number-1];
	kind = (string)target["target_kind"];
	if(search(({"boss","story_boss"}),kind)==-1)
		return (["ok":0,"message":"当前章节目标不是首领战。"]);
	return target+(["ok":1]);
}

private int safe_combat_id(string value)
{
	return value!="" && search(value," ")==-1 &&
		search(value,"\t")==-1 && search(value,"\n")==-1 &&
		search(value,"]")==-1 && search(value,":")==-1;
}

private int npc_matches_challenge(object npc,mapping target)
{
	string expected_id = (string)(target["target_combat_name"] ||
		target["combat_name"] || "");
	string expected_name = (string)(target["target_name"] ||
		target["name"] || "");
	if(expected_id!="" && functionp(npc->id) && npc->id(expected_id))
		return 1;
	return expected_name!="" && functionp(npc->query_name_cn) &&
		(string)npc->query_name_cn()==expected_name;
}

private string room_challenge_view(object me,mapping target)
{
	object room = environment(me);
	mapping(string:int) name_count = ([]);
	string listed = "";
	string actions = "";
	int npc_count;
	int match_count;
	if(!room)
		return "你处于虚空中，无法查找任务首领。\n"+
			"[返回幻境任务:illusion_realm]|[返回游戏:look]\n";
	foreach(all_inventory(room,me),object npc){
		string combat_id;
		string display_name;
		int count;
		int matched;
		if(!npc || !npc->is("npc") || !functionp(npc->query_name))
			continue;
		combat_id = (string)npc->query_name();
		if(!safe_combat_id(combat_id))
			continue;
		count = (int)name_count[combat_id];
		name_count[combat_id] = count+1;
		display_name = functionp(npc->query_name_cn) ?
			(string)npc->query_name_cn() : combat_id;
		matched = npc_matches_challenge(npc,target);
		npc_count++;
		listed += (matched ? "§y【任务首领】§r " : "· ")+
			display_name+"\n";
		if(matched){
			match_count++;
			actions += "[⚔ 挑战"+display_name+":kill "+combat_id+" "+
				(string)count+"]\n";
		}
	}
	string s = "【当前房间 NPC】\n";
	s += npc_count ? listed : "当前房间没有 NPC。\n";
	if(match_count)
		s += "\n已从房间真实对象确认任务首领；请选择挑战：\n"+
			actions;
	else
		s += "\n没有发现当前任务首领。它可能刚被其他玩家击败，"+
			"请等待刷新后重查；本次不会发起错误攻击。\n"+
			"[重新查找首领:illusion_realm challenge "+
			((string)target["target_kind"]=="route_boss" ?
			 "route" : "chapter")+"]\n";
	return s+"[查看完整场景:look]|[返回幻境任务:illusion_realm]\n";
}

string query_room_challenge_view_for_test(object me,mapping target)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return "";
	return room_challenge_view(me,target);
}

private string chapter_task_view(object me,mapping progress,mapping chapter,
	int chapter_number)
{
	string s = "\n【本章任务】\n";
	string arrival_actions = "";
	int kills = (int)chapter["chapter_kills"];
	int kills_done = (int)chapter["chapter_kills_done"];
	int bosses = (int)chapter["chapter_boss_kills"];
	int bosses_done = (int)chapter["chapter_boss_kills_done"];
	int visits = (int)chapter["chapter_visits"];
	int visits_done = (int)chapter["chapter_visits_done"];
	s += "等级：Lv"+
		(string)(int)progress["level"]+"/Lv"+
		(string)(int)chapter["min_level"]+"\n";
	if((string)chapter["experience_title"]!="")
		s += "关卡节奏：§b"+(string)chapter["experience_title"]+
			"§r　"+(string)chapter["experience_hint"]+"\n";
	if(kills>0)
		s += "狩猎："+(string)chapter["hunt_name"]+" "+
			(string)kills_done+"/"+(string)kills+"只（还差"+
			(string)max(0,kills-kills_done)+"只）　地点："+
			(string)chapter["hunt_location"]+
			((string)chapter["hunt_rhythm_mode"]=="trail" ?
			 "　追迹段落 "+(string)(int)chapter["hunt_rhythm_stage"]+"/"+
			 (string)(int)chapter["hunt_rhythm_stages"] : "")+"\n";
	if(bosses>0)
		s += "首领："+(string)chapter["boss_name"]+" "+
			(string)bosses_done+"/"+(string)bosses+"只（还差"+
			(string)max(0,bosses-bosses_done)+"只）　地点："+
			(string)chapter["boss_location"]+"\n";
	if(visits>0)
		s += "探索：本章"+(string)visits_done+"/"+(string)visits+
			"处（还差"+(string)max(0,visits-visits_done)+"处）\n";
	if((string)chapter["story_event"]!="")
		s += "关键剧情："+(string)chapter["story_event_title"]+" "+
			((int)chapter["story_ready"] ? "1/1" : "0/1")+
			"　地点："+(string)chapter["story_event_location"]+
			((string)chapter["story_event_kind"]=="boss" ?
				 "（击败剧情首领）" : "（阅读当地残响）")+"\n";
	if((int)chapter["quest_item_required"]>0)
		s += "剧情道具：【"+(string)chapter["quest_item_name"]+"】 "+
			(string)(int)chapter["quest_item_count"]+"/"+
			(string)(int)chapter["quest_item_required"]+
			((int)chapter["quest_item_substitute_ready"] ?
			 "　§g新月支线凭证已满足§r" :
			 "　来源："+(string)chapter["quest_item_source_name"]+
			"（"+(string)chapter["quest_item_drop_rate_text"]+
			"掉率，保底进度 "+
			(string)(int)chapter["quest_item_pity"]+"/"+
			(string)(int)chapter["quest_item_pity_kills"]+
			"；账号绑定且不可流转）")+"\n";
	if((int)chapter["quest_item_required"]>0 &&
	   !(int)chapter["quest_item_ready"])
		s += "[新月支线·完成本卷四幕战斗并取得剧情凭证:illusion_journey]\n";
	s += "\n§y【只做这一步】§r "+(string)chapter["target_name"];
	if((string)chapter["target_location"]!="")
		s += "　地点："+(string)chapter["target_location"];
	s += "\n";
	if((int)chapter["ready"] ||
	   (string)chapter["target_kind"]=="ready")
		s += "§g【本章任务已全部完成】§r\n"+
			chapter_claim_link(chapter_number);
	else{
		if(chapter_target_in_current_room(me,chapter))
			arrival_actions = chapter_arrival_actions(chapter);
		if(arrival_actions!="")
			s += arrival_actions;
		else
			s += chapter_next_link(chapter);
	}
	if((string)chapter["target_kind"]=="choice")
		s += "请返回当前历程完成三途择印。\n";
	else if((string)chapter["target_kind"]=="route")
		s += "请按已经选择的命途完成终章条件。\n";
	return s;
}

string query_chapter_task_view_for_test(object me,mapping progress,
	mapping chapter,int chapter_number)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return "";
	return chapter_task_view(me,progress,chapter,chapter_number);
}

private string progress_view(object me,mapping progress)
{
	string s = "";
	mapping current = ([]);
	int current_number;
	s += "路线："+(string)progress["path_name"]+"　等级："+
		(string)(int)progress["level"]+"\n";
	s += "探索："+(string)(int)progress["visits"]+
		"处　击杀："+(string)(int)progress["kills"]+
		"　首领："+(string)(int)progress["boss_kills"]+
		"　同队击杀："+(string)(int)progress["team_kills"]+"\n";
	s += "故事历程："+(string)(int)progress["chapter_claimed"]+"/"+
		(string)(int)progress["chapter_total"]+"章　剧情印记："+
		(string)(int)progress["story_event_count"]+"\n";
	if((string)progress["path"]=="pioneer")
		s += "寻星终章：隐藏月印 "+
			(string)(int)progress["route_mark_count"]+"/"+
			(string)(int)progress["route_target"]+"\n";
	else if((string)progress["path"]=="hunter")
		s += "破阵终章：不同守关首领 "+
			(string)(int)progress["route_mark_count"]+"/"+
			(string)(int)progress["route_target"]+"\n";
	else if((string)progress["path"]=="companion")
		s += "同心终章：同队击杀 "+
			(string)(int)progress["team_kills"]+"/"+
			(string)(int)progress["route_target"]+"\n";
	if((string)progress["path"]==""){
		s += "【三途择印】第二十三章前选择一次，本期不可更改：\n";
		s += "[寻星·重探索:illusion_realm path pioneer] ";
		s += "[破阵·重狩猎:illusion_realm path hunter] ";
		s += "[同心·重协作:illusion_realm path companion]\n";
	}
	s += "论剑荣誉："+(string)(int)progress["pvp_honor"]+
		"　胜场："+(string)(int)progress["pvp_wins"]+"\n";
	if(arrayp(progress["ranking_titles"]) &&
	   sizeof((array)progress["ranking_titles"]))
		s += "最新幻境荣誉："+
			(string)((array)progress["ranking_titles"])[-1]+"\n";
	foreach((array)progress["chapters"];int index;mapping chapter)
		if(!(int)chapter["claimed"]){
			current = chapter;
			current_number = index+1;
			break;
		}
	if(sizeof(current)){
		string mark = (int)current["ready"] ? "可完成" : "进行中";
		s += "\n"+(string)current["volume_title"]+"\n";
		s += "【第"+(string)current_number+"章·"+
			(string)current["title"]+"】"+mark+"\n";
		// 使用所有新旧客户端都已支持的通用图片转译协议。旧版 Vue
		// 不认识 story-image segment，会把整张章节图静默丢弃。
		s += "[imgurl picture:"+(string)current["image"]+"]\n";
		s += (string)current["intro"]+"\n";
		s += chapter_task_view(me,progress,current,current_number);
		if((int)current["reward_count"]>0)
			s += "本章过关额外获得本职业新月套装"+
				(string)(int)current["reward_count"]+"件。\n";
	}
	else{
		mapping training = SEASONALD->query_post_story_training_status(me);
		s += "\n八十一章已经全部完成；完整故事与十件套装均已写入本人物原档案。\n";
		s += "[开启长生十问:illusion_realm quiz]\n";
		if((string)progress["quiz_best_title"]!="")
			s += "幻境阅历："+(string)progress["quiz_best_title"]+
				"（最高 "+(string)(int)progress["quiz_best_score"]+
				"/10）\n";
		if((int)training["unlocked"]){
			s += "\n【归真修行】动态同级猎场 Lv"+
				(string)(int)training["level"]+"/999\n";
			if((int)training["hidden_milestone"])
				s += "已达到照命资格的120级里程碑；归真修行仍可继续至999级。\n";
			else
				s += "达到120级可计入照命资格；路线不会在120级停止。\n";
			if((int)training["complete"])
				s += "当前已经达到归真修行最高里程碑。\n";
			else
				s += "经验、VIP等级上限与掉落均沿用正式战斗规则。\n"+
					"[一键前往归真修行并挂机:illusion_realm cultivate]\n";
		}
	}
	s += "[查看九卷故事目录:illusion_realm story]\n";
	s += "[新月支线·九卷秘迹与月忆兽:illusion_journey]\n";
	s += "[任务自检与智能恢复:illusion_realm diagnose]\n";
	if(me && (string)me->query_profeId()=="zhaoming")
		s += "[照命专属·七卷四十九难:illusion_hidden]\n";
	return s;
}

private string task_diagnostic_view(object me)
{
	mapping progress = SEASONALD->query_player_progress(me);
	array chapters;
	mapping chapter;
	int chapter_number;
	int in_target;
	int autofight;
	string kind;
	string s = "【幻境任务自检】\n";
	if(!(int)progress["ok"])
		return s+"人物进度暂不可验证："+(string)progress["message"]+
			"\n本次没有重置、跳章或改写任何档案。\n"+
			"[重试自检:illusion_realm diagnose]|[返回游戏:look]\n";
	chapters = (array)progress["chapters"];
	chapter_number = (int)progress["chapter_claimed"]+1;
	if(chapter_number>sizeof(chapters))
		return s+"八十一章已经全部完成，人物档案可验证。\n"+
			"[查看九卷故事:illusion_realm story]|"+
			"[开启长生十问:illusion_realm quiz]|[返回游戏:look]\n";
	chapter = (mapping)chapters[chapter_number-1];
	kind = (string)chapter["target_kind"];
	in_target = chapter_target_in_current_room(me,chapter);
	autofight = functionp(me->query_autofight) &&
		(string)me->query_autofight()=="enable";
	s += "档案：可验证　章节："+(string)chapter_number+"/81\n";
	s += "当前："+(string)chapter["title"]+"　目标："+
		(string)chapter["target_name"]+"\n";
	s += "状态："+(in_target ? "已到目标区域" : "尚未到目标区域")+
		"　挂机："+(autofight ? "运行中" : "已停止")+"\n";
	s += "诊断码：S1-C"+(string)chapter_number+"/"+kind+
		"/room="+(string)in_target+"/afk="+(string)autofight+"\n";
	if((int)chapter["ready"] || kind=="ready")
		s += "结论：本章已经完成，可以安全领取并进入下一章。\n"+
			chapter_claim_link(chapter_number);
	else
		s += "结论：进度结构正常；智能继续会按当前状态传送、阅读剧情、"+
			"启动限章挂机或列出真实首领。\n"+
			"[▶ 智能继续当前任务:illusion_realm next]\n";
	return s+"[返回当前历程:illusion_realm]|[返回游戏:look]\n";
}

private string story_volume_view(mapping progress,int volume_number)
{
	string s;
	int start;
	array chapters = (array)progress["chapters"];
	if(volume_number<1 || volume_number>9)
		return "故事卷号无效。\n[返回故事目录:illusion_realm story]\n";
	start = (volume_number-1)*9;
	s = "【"+(string)chapters[start]["volume_title"]+"】\n";
	s += "[imgurl "+(string)chapters[start]["volume_title"]+
		"九幕图:"+(string)chapters[start]["atlas"]+"]\n";
	for(int offset=0;offset<9;offset++){
		mapping chapter = chapters[start+offset];
		int chapter_number = start+offset+1;
		string mark = (int)chapter["claimed"] ? "已完成" :
			((int)chapter["ready"] ? "可完成" :
			 (chapter_number==(int)progress["chapter_claimed"]+1 ?
			  "进行中" : "未开启"));
		s += "[第"+(string)chapter_number+"章·"+
			(string)chapter["title"]+":illusion_realm story chapter "+
			(string)chapter_number+"]　"+mark+"\n";
	}
	s += "[上一卷:illusion_realm story volume "+
		(string)max(1,volume_number-1)+"]|[下一卷:illusion_realm story volume "+
		(string)min(9,volume_number+1)+"]\n";
	s += "[返回故事目录:illusion_realm story]\n";
	return s;
}

private string story_chapter_view(object me,mapping progress,int chapter_number)
{
	array chapters = (array)progress["chapters"];
	mapping chapter;
	string s;
	int available = (int)progress["chapter_claimed"]+1;
	if(chapter_number<1 || chapter_number>sizeof(chapters))
		return "故事章号无效。\n[返回故事目录:illusion_realm story]\n";
	chapter = chapters[chapter_number-1];
	if(chapter_number>available)
		return "后续故事尚未开启，请先完成第"+(string)available+
			"章。\n[返回当前历程:illusion_realm]\n";
	s = (string)chapter["volume_title"]+"\n";
	s += "【第"+(string)chapter_number+"章·"+
		(string)chapter["title"]+"】\n";
	s += "[imgurl picture:"+(string)chapter["image"]+"]\n";
	s += (string)chapter["intro"]+"\n";
	if((int)chapter["claimed"])
		s += "\n【过关回响】\n"+(string)chapter["outro"]+"\n";
	else{
		s += chapter_task_view(me,progress,chapter,chapter_number);
	}
	s += "[返回本卷:illusion_realm story volume "+
		(string)(int)chapter["volume_number"]+"]|[返回当前历程:illusion_realm]\n";
	return s;
}

private string story_index_view(mapping progress)
{
	string s = "【"+(string)progress["story_title"]+"·九卷八十一章】\n";
	array chapters = (array)progress["chapters"];
	s += (string)progress["story_premise"]+"\n";
	s += "[imgurl 新月长生劫序幕:/xd/images/illusion_s1/story/volume_01.png]\n";
	for(int volume=1;volume<=9;volume++){
		int completed;
		int start = (volume-1)*9;
		for(int offset=0;offset<9;offset++)
			if((int)chapters[start+offset]["claimed"])
				completed++;
		s += "["+(string)chapters[start]["volume_title"]+
			":illusion_realm story volume "+(string)volume+"] "+
			(string)completed+"/9\n";
	}
	s += "\n章节必须按顺序完成；满足本章等级、战斗、探索与剧情条件后即可立即推进。\n";
	if((int)progress["chapter_claimed"]==81)
		s += "[长生十问·检验你是否记得这一路:illusion_realm quiz]\n";
	s += "[返回当前历程:illusion_realm]\n";
	return s;
}

private string story_quiz_view(mapping quiz)
{
	string s = "【新月长生劫·长生十问】\n";
	if(!(int)quiz["ok"])
		return s+(string)quiz["message"]+
			"\n[返回九卷故事:illusion_realm story]|[返回游戏:look]\n";
	if(!(int)quiz["unlocked"])
		return s+(string)quiz["message"]+
			"\n[返回当前历程:illusion_realm]|[返回游戏:look]\n";
	s += (string)quiz["intro"]+"\n";
	if(mappingp(quiz["route_epilogue"]) &&
	   sizeof((mapping)quiz["route_epilogue"])){
		mapping route_epilogue = (mapping)quiz["route_epilogue"];
		s += "\n【命途终幕·"+(string)route_epilogue["title"]+"】\n"+
			(string)route_epilogue["text"]+"\n";
	}
	if((int)quiz["attempts"]>0)
		s += "挑战次数："+(string)(int)quiz["attempts"]+
			"　最高分："+(string)(int)quiz["best_score"]+"/10"+
			((string)quiz["best_title"]!="" ? "　幻境阅历："+
			 (string)quiz["best_title"] : "")+"\n";
	if((string)quiz["status"]=="active"){
		mapping question = (mapping)quiz["question"];
		array options = (array)question["options"];
		int number = (int)question["number"];
		s += "\n【第"+(string)number+"/10问】\n"+
			(string)question["question"]+"\n";
		foreach(options;int index;string option)
			s += "["+(string)(index+1)+". "+option+
				":illusion_realm quiz answer "+(string)number+" "+
				(string)(index+1)+"]\n";
		s += "\n每题提交后立即写入原人物档案，本轮不能返回改答。\n";
	}
	else if((string)quiz["status"]=="completed"){
		s += "\n本轮得分："+(string)(int)quiz["last_score"]+
			"/10\n获得幻境阅历称号：【"+
			(string)quiz["best_title"]+"】\n";
		if((int)quiz["perfect"])
			s += "\n【满分后记·山门雪霁】\n"+
				(string)quiz["epilogue"]+"\n";
		s += "[重新挑战十问:illusion_realm quiz start]\n";
	}
	else{
		s += "\n【阅历奖励】0—4分：初闻长生；5—6分：记得来路；"+
			"7—8分：四洲知卷；9分：月下解卷；10分：人间见证者。\n";
		s += "称号只用于剧情阅历展示，不增加战斗属性；满分另解锁山门后记。\n";
		s += "[开始长生十问:illusion_realm quiz start]\n";
	}
	s += "[返回九卷故事:illusion_realm story]|[返回游戏:look]\n";
	return s;
}

private string story_quiz_answer_view(mapping result)
{
	string s = (string)result["message"];
	if(has_index(result,"correct"))
		s += "\n"+((int)result["correct"] ? "§g【答对】§r " :
			"§c【答错】§r ")+(string)result["explanation"]+"\n";
	return s+"\n"+story_quiz_view(result);
}

private string guided_follow_up(object me,mapping progress,int after_travel)
{
	int chapter_number = (int)progress["chapter_claimed"]+1;
	array chapters = (array)progress["chapters"];
	mapping chapter;
	string arrival_actions = "";
	if(chapter_number>sizeof(chapters)){
		mapping training = SEASONALD->query_post_story_training_status(me);
		return "\n【全部完成】八十一章已经通关，可在故事目录重温全部剧情。\n"+
			"[开启长生十问:illusion_realm quiz]|"+
			"[查看九卷故事目录:illusion_realm story]\n"+
			((int)training["unlocked"] && !(int)training["complete"] ?
			 "[下一步·归真修行至999级:illusion_realm cultivate]\n" : "");
	}
	chapter = (mapping)chapters[chapter_number-1];
	if(!after_travel && chapter_target_in_current_room(me,chapter))
		after_travel = 1;
	if(after_travel)
		arrival_actions = chapter_arrival_actions(chapter);
	if(arrival_actions!="")
		return arrival_actions;
	return "\n【下一步】"+(string)chapter["target_name"]+
		((string)chapter["target_location"]!="" ? "　地点："+
			(string)chapter["target_location"] : "")+"\n"+
		chapter_next_link(chapter)+"[返回游戏:look]\n";
}

private string guided_route_help(object me,mapping progress)
{
	string path = (string)progress["path"];
	mapping step = SEASONALD->query_route_step(me);
	string direct = (int)step["done"] ?
		"[▶ 下一步：领取本章并继续:illusion_realm next]\n" :
		((string)step["action"]=="team" ?
		 "[▶ 下一步：打开队伍并开始协作:team]\n" :
		 "[▶ 下一步：前往"+(string)step["location"]+"·"+
			(string)step["name"]+":illusion_realm route next]\n");
	if(path=="pioneer")
		return "【寻星终章·按顺序做】\n"+
			"1. 倒月镜湖点击观察倒月。\n"+
			"2. 隐月环坑点击勘察星核。\n"+
			"3. 新月祭坛点击合印归真。\n"+
			"当前完成："+(string)(int)progress["route_mark_count"]+"/"+
			(string)(int)progress["route_target"]+"\n"+
			direct+"[返回当前章节:illusion_realm]\n";
	if(path=="hunter")
		return "【破阵终章·按顺序打】\n"+
			"依次击败断星桥的断桥镇星使、隐月环坑的月庭巡将、"+
			"长生月炉的无影司炉者。终章归真月主只在第81章正式挑战。\n"+
			"当前完成："+(string)(int)progress["route_mark_count"]+"/"+
			(string)(int)progress["route_target"]+"\n"+
			direct+"[返回当前章节:illusion_realm]\n";
	return "【同心终章·只做一件事】\n"+
		"和队友待在同一房间打怪，累计同队击杀"+
		(string)(int)progress["route_target"]+"只。当前："+
		(string)(int)progress["team_kills"]+"/"+
		(string)(int)progress["route_target"]+"\n"+
		direct+"[开始自动打怪:autofight start]|"+
		"[返回当前章节:illusion_realm]\n";
}

private string resume_chapter_after_arrival(object me,mapping progress,
	mapping chapter,int chapter_number)
{
	string kind = (string)chapter["target_kind"];
	if(!chapter_target_in_current_room(me,chapter))
		return "【幻境到达校验】人物尚未到达当前任务地点，本次没有执行任务动作。\n"+
			"[重新查看本章:illusion_realm]|[返回游戏:look]\n";
	if(kind=="story_echo"){
		mapping witnessed = SEASONALD->discover_story_event(me);
		progress = SEASONALD->query_player_progress(me);
		if(!(int)witnessed["ok"])
			return (string)witnessed["message"]+
				"\n[重试阅读剧情:illusion_realm next]|[返回游戏:look]\n";
		return "【剧情步骤完成】"+(string)witnessed["message"]+
			guided_follow_up(me,progress,0);
	}
	if(kind=="hunt"){
		mapping started = SEASONALD->start_chapter_hunt_autofight(me);
		progress = SEASONALD->query_player_progress(me);
		return (string)started["message"]+
			((int)started["ok"] ?
			 "\n[查看挂机状态:autofight]|[查看本章进度:illusion_realm]\n" :
			 guided_follow_up(me,progress,1));
	}
	if(search(({"boss","story_boss"}),kind)!=-1){
		mapping target = current_challenge_target(me,"chapter");
		if(!(int)target["ok"])
			return (string)target["message"]+
				"\n[重新查找任务首领:illusion_realm challenge chapter]|"+
				"[返回游戏:look]\n";
		return room_challenge_view(me,target);
	}
	return guided_follow_up(me,progress,1);
}

// 跨 Worker 到达后只执行“目标节点续跑”，绝不重放来源节点的移动。
// 同一命令重复到达也只会继续当前章，且必须先通过真实房间校验。
string query_arrival_resume_view(object me)
{
	mapping progress;
	array chapters;
	mapping chapter;
	int chapter_number;
	if(!me)
		return "人物会话不存在。\n";
	progress = SEASONALD->query_player_progress(me);
	if(!(int)progress["ok"])
		return (string)progress["message"]+"\n[返回游戏:look]\n";
	chapters = (array)progress["chapters"];
	chapter_number = (int)progress["chapter_claimed"]+1;
	if(chapter_number<1 || chapter_number>sizeof(chapters))
		return progress_view(me,progress);
	chapter = (mapping)chapters[chapter_number-1];
	if((int)chapter["ready"] || (string)chapter["target_kind"]=="ready")
		return progress_view(me,progress);
	if((string)chapter["target_kind"]=="choice")
		return progress_view(me,progress);
	if((string)chapter["target_kind"]=="route")
		return guided_route_help(me,progress);
	return resume_chapter_after_arrival(me,progress,chapter,chapter_number);
}

private string guided_next_step(object me)
{
	mapping progress = SEASONALD->query_player_progress(me);
	array chapters;
	mapping chapter;
	mapping result;
	int chapter_number;
	string kind;
	if(!(int)progress["ok"])
		return (string)progress["message"]+"\n[返回游戏:look]\n";
	chapters = (array)progress["chapters"];
	chapter_number = (int)progress["chapter_claimed"]+1;
	if(chapter_number>sizeof(chapters))
		return guided_follow_up(me,progress,0);
	chapter = (mapping)chapters[chapter_number-1];
	kind = (string)chapter["target_kind"];
	if((int)chapter["ready"] || kind=="ready"){
		result = SEASONALD->claim_chapter_reward(me,chapter_number);
		progress = SEASONALD->query_player_progress(me);
		return (string)result["message"]+
			((int)result["ok"] ? guided_follow_up(me,progress,0) :
			 "\n[重新查看本章:illusion_realm]|[返回游戏:look]\n");
	}
	if(kind=="choice")
		return progress_view(me,progress);
	if(kind=="route")
		return guided_route_help(me,progress);
	if(functionp(me->query_autofight) &&
	   (string)me->query_autofight()=="enable")
		AUTOFIGHTD->stop_autofight(me);
	result = SEASONALD->travel_to_chapter_target(me,chapter_number);
	if(!(int)result["ok"])
		return (string)result["message"]+
			"\n[重新查看本章:illusion_realm]|[返回游戏:look]\n";
	// 同 Worker 直接执行；跨 Worker 时来源对象尚未真正到达，这一返回
	// 会被网关的 illusion_arrived 目标命令替换。
	return (string)result["message"]+"\n"+
		resume_chapter_after_arrival(me,progress,chapter,chapter_number);
}

private string ranking_menu(mapping status)
{
	int starts_at = (int)status["starts_at"];
	int current_week = starts_at>0 ?
		min(60,max(1,1+(time()-starts_at)/(7*86400))) : 1;
	string period = "week:"+(string)current_week;
	string s = "【"+(string)status["illusion_id"]+"幻境排行榜】\n";
	array(mapping(string:string)) boards = ({
		(["id":"journey","name":"征途"]),(["id":"level","name":"境界"]),
		(["id":"experience","name":"经验"]),(["id":"pk","name":"论剑"]),
		(["id":"set","name":"套装"]),(["id":"speed","name":"极速"]),
	});
	foreach(boards,mapping board){
		s += "["+(string)board["name"]+"总榜:illusion_realm rank "+
			(string)board["id"]+" overall] ";
		s += "[本周:illusion_realm rank "+(string)board["id"]+" "+
			period+"]\n";
	}
	s += "\n周榜结束后前十可领取荣誉称号；总榜在本期结束后结算。\n";
	s += "同注册账号切磋不计分；同一对手每日仅前三次按100/50/20递减；等级碾压不计分。\n";
	s += "称号仅用于展示收藏，不增加永久战斗属性。\n";
	s += "[返回幻境区:illusion_realm]\n";
	return s;
}

private string ranking_view(mapping status,string board,string period)
{
	mapping result = SEASONALD->query_illusion_leaderboard(
		(string)status["illusion_id"],board,period,20);
	string s;
	if(!(int)result["ok"])
		return (string)result["message"]+"\n[返回排行榜:illusion_realm rank]\n";
	s = "【"+(string)result["board_name"]+"·"+
		(period=="overall" ? "总榜" : "第"+period[5..]+"周")+"】\n";
	if(!sizeof((array)result["rows"]))
		s += "尚无符合条件的榜单记录。\n";
	foreach((array)result["rows"],mapping row)
		s += (string)(int)row["rank"]+". "+(string)row["name_cn"]+
			"（"+(string)row["profession_name"]+"） "+
			(string)row["score_text"]+"\n";
	s += "\n[领取本榜前十荣誉:illusion_realm rank claim "+board+" "+
		period+"]\n[返回排行榜:illusion_realm rank]\n";
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	mapping status = SEASONALD->query_public_status();
	mapping story_access;
	mapping account_data;
	string s = "";
	array(string) parts = arg ? String.trim_all_whites(arg)/" " : ({});
	if(!me){
		write("人物会话不存在。\n");
		return 1;
	}
	story_access=SEASONALD->query_story_access(me);
	if(sizeof(parts)>=2 && parts[0]=="echo" && parts[1]=="enter"){
		string illusion_id=sizeof(parts)>=3 ? parts[2] : "";
		mapping result=SEASONALD->enter_eternal_echo(me,illusion_id);
		write((string)result["message"]+
			((int)result["ok"] ?
			 "\n[查看回响任务:illusion_realm]|[返回游戏:look]\n" :
			 "\n[返回幻境区:illusion_realm]|[返回游戏:look]\n"));
		return 1;
	}
	if(sizeof(parts)>=2 && parts[0]=="echo" && parts[1]=="leave"){
		mapping result=SEASONALD->leave_eternal_echo(me);
		write((string)result["message"]+
			"\n[返回幻境区:illusion_realm]|[返回游戏:look]\n");
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="challenge"){
		string scope = sizeof(parts)>=2 && parts[1]=="route" ?
			"route" : "chapter";
		mapping target = current_challenge_target(me,scope);
		if(!(int)target["ok"])
			write((string)target["message"]+
				"\n[返回幻境任务:illusion_realm]|[返回游戏:look]\n");
		else
			write(room_challenge_view(me,target));
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="diagnose"){
		write(task_diagnostic_view(me));
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="next"){
		write(guided_next_step(me));
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="hunt"){
		mapping result = SEASONALD->start_chapter_hunt_autofight(me);
		write((string)result["message"]+
			((int)result["ok"] ?
			 "\n[查看挂机状态:autofight]|[查看本章进度:illusion_realm]\n" :
			 "\n[▶ 下一步：前往任务地点:illusion_realm next]|[返回游戏:look]\n"));
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="cultivate"){
		mapping training = SEASONALD->query_post_story_training_status(me);
		mapping route;
		if(!(int)training["ok"] || !(int)training["unlocked"]){
			write((string)training["message"]+
				"\n[返回幻境任务:illusion_realm]|[返回游戏:look]\n");
			return 1;
		}
		if((int)training["complete"]){
			write("归真修行已经达到999级。\n"+
				"[返回幻境任务:illusion_realm]|[返回游戏:look]\n");
			return 1;
		}
		if((string)training["mode"]=="echo"){
			mapping access = SEASONALD->query_story_access(me);
			if(!(int)access["in_content_room"]){
				mapping entered = SEASONALD->enter_eternal_echo(me,"S1");
				if(!(int)entered["ok"]){
					write((string)entered["message"]+
						"\n[重试:illusion_realm cultivate]|[返回游戏:look]\n");
					return 1;
				}
			}
		}
		string reason = AUTOFIGHTD->query_start_block_reason(me);
		if(reason!=""){
			AUTOFIGHTD->stop_autofight(me);
			write("无法启动归真修行："+reason+
				"\n[重试:illusion_realm cultivate]|[返回游戏:look]\n");
			return 1;
		}
		route = AUTOFIGHTD->query_balanced_training_route(me);
		if(!sizeof(route) || !(int)route["post_story_training"]){
			write("归真路线暂不可验证，本次没有启动挂机或移动人物。\n"+
				"[重试:illusion_realm cultivate]|[返回游戏:look]\n");
			return 1;
		}
		AUTOFIGHTD->start_autofight(me);
		int moved = AUTOFIGHTD->move_to_training_route(me,route);
		write("归真修行已启动：动态怪会沿用现有正式战斗、经验与掉落规则。"+
			(moved ? "\n已前往当前较空闲的归真猎场。" :
			 "\n正在安全寻路，下一次挂机心跳会继续前往归真猎场。")+
			"\n[查看挂机状态:autofight]|[返回幻境任务:illusion_realm]\n");
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="quiz"){
		if(sizeof(parts)>=4 && parts[1]=="answer"){
			mapping answered = SEASONALD->answer_story_quiz(
				me,(int)parts[2],(int)parts[3]);
			write(story_quiz_answer_view(answered));
			return 1;
		}
		if(sizeof(parts)>=2 && parts[1]=="start"){
			mapping started = SEASONALD->start_story_quiz(me);
			write(story_quiz_view(started));
			return 1;
		}
		write(story_quiz_view(SEASONALD->query_story_quiz(me)));
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="rank"){
		if(sizeof(parts)>=4 && parts[1]=="claim"){
			mapping reward = SEASONALD->claim_illusion_ranking_reward(
				me,parts[2],parts[3]);
			write((string)reward["message"]+
				"\n[返回排行榜:illusion_realm rank]\n");
			return 1;
		}
		if(sizeof(parts)>=2){
			string period = sizeof(parts)>=3 ? parts[2] : "overall";
			write(ranking_view(status,parts[1],period));
			return 1;
		}
		write(ranking_menu(status));
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="story"){
		mapping progress = SEASONALD->query_player_progress(me);
		if(!(int)progress["ok"]){
			write((string)progress["message"]+"\n[返回游戏:look]\n");
			return 1;
		}
		if(sizeof(parts)>=3 && parts[1]=="travel"){
			mapping travel = SEASONALD->travel_to_chapter_target(
				me,(int)parts[2]);
			if((int)travel["ok"]){
				progress=SEASONALD->query_player_progress(me);
				write((string)travel["message"]+
					guided_follow_up(me,progress,1));
			}
			else
				write((string)travel["message"]+
					"\n[重新查看本章:illusion_realm]|[返回游戏:look]\n");
		}
		else if(sizeof(parts)>=3 && parts[1]=="chapter")
			write(story_chapter_view(me,progress,(int)parts[2]));
		else if(sizeof(parts)>=3 && parts[1]=="volume")
			write(story_volume_view(progress,(int)parts[2]));
		else
			write(story_index_view(progress));
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="activate"){
		if(sizeof(parts)<2 || parts[1]!="confirm"){
			write(((int)status["entitlement_cost_suiyu"]>0 ?
				"永久解锁"+(string)status["illusion_id"]+"人物资格需要"+
				(string)(int)status["entitlement_cost_suiyu"]+"枚碎玉。" :
				(string)status["illusion_id"]+"赛季资格登记本身不扣费。")+
				"资格属于注册账号且仅限本赛季；创建首个及后续每个人物都需要100碎玉栏位，500碎玉可购买5格。\n"+
				"[确认登记赛季资格:illusion_realm activate confirm]\n"+
				"[取消:illusion_realm]\n");
			return 1;
		}
		// HTTP commands are serialized by their account runtime mutex; legacy
		// socket commands run on the main event thread. The daemon's entitlement
		// index write is atomic and resolves cross-character purchase races.
		mapping result = SEASONALD->purchase_entitlement(me);
		write((string)result["message"]+"\n[返回幻境区:illusion_realm]\n");
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="expand"){
		mapping expansion_account = ACCOUNT_CHARACTERD->
			query_account_characters((string)me->query_account_owner(),
				(string)status["illusion_id"]);
		int spent = (int)expansion_account[
			"illusion_expansion_spent_suiyu"];
		int slots = (int)expansion_account["illusion_character_slots"];
		if(!(int)expansion_account["ok"]){
			write("账号栏位状态暂不可验证，本次不会扣除碎玉。\n"+
				"[返回幻境区:illusion_realm]\n");
			return 1;
		}
		if(!(int)expansion_account["illusion_entitled"]){
			write("请先登记"+(string)status["illusion_id"]+
				"赛季资格；登记不扣费，人物栏位另行付费。\n"+
				"[登记赛季资格:illusion_realm activate]|"+
				"[返回幻境区:illusion_realm]\n");
			return 1;
		}
		if(sizeof(parts)<2 || search(({"one","all"}),parts[1])==-1){
			write("【幻境人物栏位】\n当前赛季栏位："+(string)slots+
				"个　累计已计入："+(string)spent+"碎玉\n"+
				"[100碎玉增加本期1格:illusion_realm expand one]|"+
				"[500碎玉一次购买本期5格:illusion_realm expand all]\n"+
				"每一期独立购买；没有免费首格，也不会把S1栏位带入S2。\n"+
				"[返回幻境区:illusion_realm]\n");
			return 1;
		}
		string option = parts[1];
		int cost = option=="one" ? 100 : 500;
		if(sizeof(parts)<3 || parts[2]!="confirm"){
			write((option=="one" ?
				"确认支付100碎玉，增加1个本期幻境人物栏位？" :
				"确认支付"+(string)cost+
				"碎玉，一次购买5个本期人物栏位？")+"\n"+
				"[确认支付:illusion_realm expand "+option+" confirm]|"+
				"[取消:illusion_realm expand]\n");
			return 1;
		}
		mapping expansion = SEASONALD->purchase_character_expansion(me,option);
		write((string)expansion["message"]+
			"\n[查看栏位:illusion_realm expand]|"+
			"[返回幻境区:illusion_realm]\n");
		return 1;
	}
	if(sizeof(parts)>=2 && parts[0]=="route" && parts[1]=="next"){
		if(functionp(me->query_autofight) &&
		   (string)me->query_autofight()=="enable")
			AUTOFIGHTD->stop_autofight(me);
		mapping result = SEASONALD->travel_to_route_target(me);
		string follow = "\n[重新查看终章指引:illusion_realm next]|"+
			"[返回游戏:look]\n";
		if((int)result["ok"] && (int)result["done"])
			follow = "\n[▶ 下一步：领取本章并继续:illusion_realm next]\n";
		else if((int)result["ok"] && (string)result["action"]=="explore")
			follow = "\n[▶ 下一步：取得当前月印:illusion_realm explore]\n";
		else if((int)result["ok"] && (string)result["action"]=="hunt")
			follow = "\n"+boss_challenge_link(result)+
				"[返回游戏:look]|[重新查看终章指引:illusion_realm next]\n";
		else if((int)result["ok"] && (string)result["action"]=="team")
			follow = "\n[▶ 下一步：打开队伍:team]|"+
				"[开始自动打怪:autofight start]\n";
		write((string)result["message"]+follow);
		return 1;
	}
	if(sizeof(parts)>=2 && parts[0]=="path"){
		mapping result = SEASONALD->choose_player_path(me,parts[1]);
		write((string)result["message"]+
			((int)result["ok"] ?
			 "\n[▶ 下一步：继续本章:illusion_realm next]|[返回游戏:look]\n" :
			 "\n[重新选择命途:illusion_realm]|[返回游戏:look]\n"));
		return 1;
	}
	if(sizeof(parts)>=2 && parts[0]=="claim"){
		mapping result = SEASONALD->claim_chapter_reward(me,(int)parts[1]);
		mapping progress = SEASONALD->query_player_progress(me);
		write((string)result["message"]+
			((int)result["ok"] ? guided_follow_up(me,progress,0) :
			 "\n[返回当前章节:illusion_realm]|[返回游戏:look]\n"));
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="explore"){
		mapping result = SEASONALD->discover_route_secret(me);
		write((string)result["message"]+
			((int)result["ok"] ?
			 "\n[▶ 下一步：继续本章:illusion_realm next]|[返回游戏:look]\n" :
			 "\n[重试当前探索:illusion_realm explore]|[返回游戏:look]\n"));
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="witness"){
		mapping result = SEASONALD->discover_story_event(me);
		write((string)result["message"]+
			((int)result["ok"] ?
			 "\n[▶ 下一步：继续本章:illusion_realm next]|[返回游戏:look]\n" :
			 "\n[重试阅读剧情:illusion_realm witness]|[返回游戏:look]\n"));
		return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="return"){
		write("管理员关闭本期后由系统自动安全回归，无需重复点击；保存失败会自动重试。\n"+
			"[返回幻境区:illusion_realm]\n");
		return 1;
	}
	s += "【"+(string)status["display_name"]+"】\n";
	s += "阶段："+(string)status["phase_name"]+"\n";
	s += "开始："+time_text((int)status["starts_at"])+"\n";
	if((string)status["phase"]=="active")
		s += "本期持续开放，只有管理员关闭后才开始回归结算。\n";
	else if((string)status["phase"]=="settling" ||
	   (string)status["phase"]=="closed")
		s += "管理员关闭："+time_text((int)status["ends_at"])+"\n";
	if(!(int)status["ok"])
		s += "配置或运行状态校验失败，功能已安全关闭。\n";
	account_data = ACCOUNT_CHARACTERD->query_account_characters(
		(string)me->query_account_owner(),(string)status["illusion_id"]);
	if((int)account_data["illusion_entitled"]){
		s += (string)status["illusion_id"]+"永久人物资格：已解锁\n";
		s += "人物栏位：本期"+
			(string)(int)account_data["illusion_character_slots"]+
			"格　累计支付"+
			(string)(int)account_data["illusion_expansion_spent_suiyu"]+
			"碎玉　[购买人物栏位:illusion_realm expand]\n";
	}
	else if((int)status["entitlement_open"])
		s += (string)status["illusion_id"]+
			"赛季资格：未登记　[登记资格（人物栏位另付费）:illusion_realm activate]\n";
	else
		s += (string)status["illusion_id"]+
			"永久人物资格：当前未开放激活\n";
	if((int)story_access["ok"]){
		mapping progress = SEASONALD->query_player_progress(me);
			if((string)story_access["mode"]=="echo"){
			s += "\n【永恒回响】本期赛季榜已经冻结；你仍可完整体验81章，章节与套装每个角色只结算一次。\n";
				s += "[进入"+(string)story_access["illusion_id"]+
					"永恒回响:illusion_realm echo enter "+
					(string)story_access["illusion_id"]+"]"+
					((int)story_access["in_content_room"] ?
					 "|[离开回响:illusion_realm echo leave]" : "")+"\n";
		}
		if((int)progress["ok"])
			s += "\n"+progress_view(me,progress);
		if((string)status["phase"]=="settling" ||
		   (string)status["phase"]=="closed")
			s += "\n系统正在自动安全回归；保存失败会自动重试。\n";
	}
	else if((int)status["creation_open"] &&
	   (int)account_data["illusion_entitled"])
		s += "请回到账号人物中心，选择“"+
			(string)status["display_name"]+"”创建本期人物。\n";
	s += "\n【回归规则】人物始终只有一份原档案；已领取套装随原档案回归，不复制背包。\n";
	s += "【家园规则】幻境人物本期不开放家园；回归永恒服后恢复普通家园玩法。\n";
	if(SEASONALD->is_active_illusion_character(me))
		s += "[幻境排行榜:illusion_realm rank]\n";
	if(!(int)story_access["ok"] &&
	   sizeof((array)(story_access["echoes"] || ({})))){
		s += "\n【已开放的永恒回响】\n";
		foreach((array)story_access["echoes"],mapping echo)
			s += "[进入"+(string)echo["display_name"]+":illusion_realm echo enter "+
				(string)echo["illusion_id"]+"]\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
