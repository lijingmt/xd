#include <command.h>
#include <gamelib/include/gamelib.h>

private string stage_name(int stage)
{
	return ({"尚未结契","月丝结契","雾林初鸣","三途共鸣",
		"四洲照影","人间月灵"})[max(0,min(5,stage))];
}

private string quest_view(mapping view)
{
	string s = "【新月回响·九卷秘迹】\n";
	mapping current = mappingp(view["current_quest"]) ?
		(mapping)view["current_quest"] : ([]);
	foreach((array)view["quests"],mapping quest){
		string mark = (int)quest["completed"] ? "已完成" :
			((int)quest["unlocked"] ? "进行中" : "未开启");
		s += "第"+(string)(int)quest["volume"]+"卷·"+
			(string)quest["title"]+"　"+mark;
		if((int)quest["unlocked"] && !(int)quest["completed"])
			s += "（"+(string)(int)quest["act"]+"/4幕）";
		s += "\n";
	}
	if(sizeof(current)){
		mapping act = (mapping)current["current_act"];
		s += "\n【当前秘迹·"+(string)current["title"]+"】\n";
		s += "第"+(string)((int)current["act"]+1)+"/4幕·"+
			(string)act["title"]+"\n"+(string)act["text"]+"\n";
		s += "地点："+(string)act["location"]+"\n";
		if((int)current["act"]==3 && !(int)current["final_event_ready"])
			s += "收束条件：先完成本卷主线关键剧情。\n";
		s += "[▶ 一键前往当前秘迹:illusion_journey travel]|"+
			"[观察并记录这一幕:illusion_journey advance]\n";
	}
	else if((int)view["chapter_claimed"]>=81)
		s += "\n九卷秘迹已经全部完成。\n";
	else
		s += "\n当前卷秘迹已经完成；推进主线到下一卷后继续开放。\n";
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
		write((string)result["message"]+
			((int)result["ok"] ? "\n[观察并记录这一幕:illusion_journey advance]" :
			 "\n[重试前往:illusion_journey travel]")+
			"|[返回秘迹:illusion_journey quests]|[返回游戏:look]\n");
		return 1;
	}
	if(sizeof(parts) && parts[0]=="advance"){
		result = ILLUSION_JOURNEYD->advance_current_quest(me);
		write((string)result["message"]+"\n[继续九卷秘迹:illusion_journey quests]|"+
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
