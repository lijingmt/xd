#include <command.h>
#include <gamelib/include/gamelib.h>

private string stage_name(int stage)
{
	return ({"尚未结契","月丝结契","雾林初鸣","三途共鸣",
		"四洲照影","人间月灵"})[max(0,min(5,stage))];
}

private int safe_combat_id(string value)
{
	return value!="" && search(value," ")==-1 &&
		search(value,"\t")==-1 && search(value,"\n")==-1 &&
		search(value,"]")==-1 && search(value,":")==-1;
}

private string normalized_object_path(object value)
{
	string path = value ? file_name(value) : "";
	if(has_prefix(path,ROOT))
		path = path[sizeof(ROOT)..];
	if(search(path,"#")!=-1)
		path = (path/"#")[0];
	return path;
}

private string sidequest_battle_actions(mapping current)
{
	if((int)current["act_ready"])
		return "[记录战果并进入下一幕:illusion_journey advance]\n";
	if((int)current["act"]==3)
		return "[返回幻境主线挑战卷末首领:illusion_realm]|"+
			"[刷新支线进度:illusion_journey quests]\n";
	return "[⚔ 查找并挑战支线目标:illusion_journey challenge]|"+
		"[支线挂机至本幕完成:illusion_journey hunt]\n";
}

private string room_challenge_view(object me,mapping current)
{
	object room = environment(me);
	mapping act = mappingp(current["current_act"]) ?
		(mapping)current["current_act"] : ([]);
	mapping(string:int) name_count = ([]);
	string listed = "";
	string actions = "";
	int npc_count;
	int match_count;
	if(!room || !sizeof(act))
		return "当前支线战场不可验证。\n[返回新月支线:illusion_journey quests]|[返回游戏:look]\n";
	if(!MAP_WORKERD->static_room_locations_match(file_name(room),
	   (string)act["room"]))
		return "请先前往【"+(string)act["location"]+"】。\n"+
			"[一键前往支线战场:illusion_journey travel]|"+
			"[返回游戏:look]\n";
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
		matched = normalized_object_path(npc)==(string)act["target_path"];
		npc_count++;
		listed += (matched ? "§y【支线目标】§r " : "· ")+display_name+"\n";
		if(matched){
			match_count++;
			actions += "[⚔ 挑战"+display_name+":kill "+combat_id+" "+
				(string)count+"]\n";
		}
	}
	string s = "【新月支线·当前战场】\n";
	s += npc_count ? listed : "当前房间没有NPC。\n";
	if(match_count)
		s += "\n已从房间真实对象确认支线目标：\n"+actions;
	else
		s += "\n支线目标可能刚被其他玩家击败，请等待刷新；本次不会攻击错误对象。\n"+
			"[重新查找:illusion_journey challenge]\n";
	return s+"[查看支线进度:illusion_journey quests]|[返回游戏:look]\n";
}

private string quest_view(mapping view)
{
	string s = "【新月支线·九卷秘迹】\n";
	s += "这是可选支线，不会替代八十一章主线；每幕需要完成真实战斗，"+
		"卷末复用本卷主线首领战。\n";
	mapping current = mappingp(view["current_quest"]) ?
		(mapping)view["current_quest"] : ([]);
	foreach((array)view["quests"],mapping quest){
		string mark = (int)quest["completed"] ? "已完成" :
			((int)quest["unlocked"] ? "进行中" : "未开启");
		s += "第"+(string)(int)quest["volume"]+"卷支线·"+
			(string)quest["title"]+"　"+mark;
		if((int)quest["unlocked"] && !(int)quest["completed"])
			s += "（"+(string)(int)quest["act"]+"/4幕）";
		s += "\n";
	}
	if(sizeof(current)){
		mapping act = (mapping)current["current_act"];
		s += "\n【当前支线任务·"+(string)current["title"]+"】\n";
		s += "第"+(string)((int)current["act"]+1)+"/4幕·"+
			(string)act["title"]+"\n"+(string)act["text"]+"\n";
		s += "战斗目标："+(string)act["target_name"]+" "+
			(string)(int)current["act_kills"]+"/"+
			(string)(int)current["required_kills"]+"只\n";
		s += "地点："+(string)act["location"]+"\n";
		if((int)current["act"]==3 && !(int)current["final_event_ready"])
			s += "收束条件：先完成本卷主线关键剧情并击败卷末首领。\n";
		s += "[▶ 一键前往支线战场:illusion_journey travel]|"+
			"[返回游戏:look]\n"+sidequest_battle_actions(current);
	}
	else if((int)view["chapter_claimed"]>=81)
		s += "\n九卷新月支线已经全部完成。\n";
	else
		s += "\n当前卷支线已经完成；推进主线到下一卷后继续开放。\n";
	return s+"[月忆兽:illusion_journey pet]|"+
		"[行旅秘术:illusion_journey secrets]\n"+
		"[返回幻境任务:illusion_realm]|[返回游戏:look]\n";
}

private string secret_view(mapping view)
{
	string s = "【新月回响·行旅秘术】\n";
	mapping owned = (mapping)view["secrets"];
	foreach((array)view["secret_catalog"],mapping secret){
		int have = (int)owned[(string)secret["id"]]>0;
		s += (have ? "§g【已悟】§r " : "【未悟】")+
			(string)secret["name"]+"·"+(string)secret["kind"]+"\n"+
			(string)secret["description"]+"\n";
		if(have)
			s += "[施展"+(string)secret["name"]+":illusion_journey use "+
				(string)secret["id"]+"]\n";
	}
	s += "\n秘术只改变探索、线索与叙事交互；不进入普通武功栏，"+
		"不增加PVP或职业战斗数值。\n";
	return s+"[返回九卷秘迹:illusion_journey quests]|"+
		"[返回游戏:look]\n";
}

private string companion_view(mapping view)
{
	mapping companion = (mapping)view["companion"];
	array catalog = (array)companion["catalog"];
	string s = "【新月回响·月忆兽】\n";
	if(!(int)companion["memory_count"] &&
	   (string)companion["active_id"]==""){
		s += "完成第一卷秘迹后，无名月茧会回应你的选择。\n";
		foreach(catalog,mapping species)
			if(search(({"ink_tail","fog_horn","mirror_fin"}),
			   (string)species["id"])!=-1)
				s += "[选择"+(string)species["name"]+
					":illusion_journey pet choose "+
					(string)species["id"]+"]　"+
					(string)species["gift"]+"\n";
		return s+"[返回九卷秘迹:illusion_journey quests]|"+
			"[返回游戏:look]\n";
	}
	s += "羁绊阶段："+stage_name((int)companion["stage"])+
		"　卷间记忆："+(string)(int)companion["memory_count"]+"/9\n";
	s += "性格：勇气"+(string)(int)((mapping)companion["traits"])["courage"]+
		"　体恤"+(string)(int)((mapping)companion["traits"])["care"]+
		"　好奇"+(string)(int)((mapping)companion["traits"])["curiosity"]+
		"　自由"+(string)(int)((mapping)companion["traits"])["freedom"]+"\n\n";
	s += "【同行图鉴】\n";
	foreach(catalog,mapping species){
		if(!(int)species["owned"])
			continue;
		s += ((int)species["active"] ? "§g【同行】§r " : "【已遇】")+
			(string)species["name"]+"　"+(string)species["gift"]+"\n";
		if(!(int)species["active"])
			s += "[邀请同行:illusion_journey pet active "+
				(string)species["id"]+"]\n";
	}
	if((int)companion["memory_count"]<9){
		mapping memory = (mapping)companion["next_memory"];
		s += "\n【下一段月忆·"+(string)memory["title"]+"】\n"+
			(string)memory["text"]+"\n";
		foreach((array)companion["choices"],mapping choice)
			s += "["+(string)choice["name"]+":illusion_journey pet memory "+
				(string)choice["id"]+"]\n";
		s += "每卷秘迹完成后记录一段；选择只塑造性格、台词与行旅册，"+
			"不改变战斗奖励。\n";
	}
	s += "\n月忆兽保存在当前S1角色原档案，不改写共享宠物或本命灵伴；"+
		"本版作为探索同行与赛季遗产，不另造战斗公式。\n";
	return s+"[返回九卷秘迹:illusion_journey quests]|"+
		"[返回游戏:look]\n";
}

int main(string|zero arg)
{
	object me = this_player();
	array(string) parts = arg ? String.trim_all_whites(arg)/" " : ({});
	mapping view;
	mapping result;
	if(!me){
		write("人物会话不存在。\n");
		return 1;
	}
	view = ILLUSION_JOURNEYD->query_journey(me);
	if(!(int)view["ok"]){
		write((string)view["message"]+"\n[返回幻境任务:illusion_realm]|[返回游戏:look]\n");
		return 1;
	}
	if(sizeof(parts) && parts[0]=="travel"){
		result = ILLUSION_JOURNEYD->travel_to_current_quest(me);
		view = ILLUSION_JOURNEYD->query_journey(me);
		write((string)result["message"]+"\n"+
			((int)result["ok"] && mappingp(view["current_quest"]) ?
			 sidequest_battle_actions((mapping)view["current_quest"]) :
			 "[重试前往:illusion_journey travel]\n")+
			"[返回新月支线:illusion_journey quests]|[返回游戏:look]\n");
		return 1;
	}
	if(sizeof(parts) && parts[0]=="challenge"){
		mapping current = mappingp(view["current_quest"]) ?
			(mapping)view["current_quest"] : ([]);
		if(!sizeof(current) || (int)current["act_ready"] ||
		   (int)current["act"]==3)
			write("当前没有可从支线页直接挑战的普通目标。\n"+
				"[返回新月支线:illusion_journey quests]|[返回游戏:look]\n");
		else
			write(room_challenge_view(me,current));
		return 1;
	}
	if(sizeof(parts) && parts[0]=="hunt"){
		result = ILLUSION_JOURNEYD->start_current_quest_hunt(me);
		write((string)result["message"]+
			((int)result["ok"] ? "\n[查看挂机状态:autofight]|" : "\n")+
			"[返回新月支线:illusion_journey quests]|[返回游戏:look]\n");
		return 1;
	}
	if(sizeof(parts) && parts[0]=="advance"){
		result = ILLUSION_JOURNEYD->advance_current_quest(me);
		write((string)result["message"]+"\n[继续新月支线:illusion_journey quests]|"+
			"[返回幻境任务:illusion_realm]|[返回游戏:look]\n");
		return 1;
	}
	if(sizeof(parts)>=2 && parts[0]=="use"){
		result = ILLUSION_JOURNEYD->use_secret(me,parts[1]);
		write((string)result["message"]+"\n[返回行旅秘术:illusion_journey secrets]|"+
			"[返回游戏:look]\n");
		return 1;
	}
	if(sizeof(parts)>=3 && parts[0]=="pet" && parts[1]=="choose"){
		result = ILLUSION_JOURNEYD->choose_starter_companion(me,parts[2]);
		write((string)result["message"]+"\n[返回月忆兽:illusion_journey pet]|"+
			"[返回游戏:look]\n");
		return 1;
	}
	if(sizeof(parts)>=3 && parts[0]=="pet" && parts[1]=="active"){
		result = ILLUSION_JOURNEYD->choose_active_companion(me,parts[2]);
		write((string)result["message"]+"\n[返回月忆兽:illusion_journey pet]|"+
			"[返回游戏:look]\n");
		return 1;
	}
	if(sizeof(parts)>=3 && parts[0]=="pet" && parts[1]=="memory"){
		result = ILLUSION_JOURNEYD->claim_companion_memory(me,parts[2]);
		write((string)result["message"]+"\n[返回月忆兽:illusion_journey pet]|"+
			"[返回游戏:look]\n");
		return 1;
	}
	view = ILLUSION_JOURNEYD->query_journey(me);
	if(sizeof(parts) && parts[0]=="secrets")
		write(secret_view(view));
	else if(sizeof(parts) && parts[0]=="pet")
		write(companion_view(view));
	else
		write(quest_view(view));
	return 1;
}
