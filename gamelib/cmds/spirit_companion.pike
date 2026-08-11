/** 本命灵伴：角色独立的收集、培养、装备与战斗位操作界面。 */

#include <command.h>
#include <gamelib/include/gamelib.h>

private mapping find_spirit_pet(mapping state,string pet_id)
{
	foreach((array)(state["pets"] || ({})),mapping pet)
		if((string)pet["id"]==pet_id)
			return pet;
	return ([]);
}

private string render_spirit_starters()
{
	string result = "§5【本命初遇】§r\n\n";
	result += "请选择这个角色的第一位本命灵伴。以后可通过灵境寻踪继续收集；选择只影响初遇顺序，不会错过图鉴。\n\n";
	foreach(SPIRIT_COMPANIOND->query_spirit_companion_starters(),
	   string species){
		mapping info = SPIRIT_COMPANIOND->
			query_spirit_companion_catalog()[species];
		result += "§5"+(string)info["icon"]+" "+
			(string)info["name"]+"§r · "+(string)info["combat"]+"\n"+
			(string)info["temperament"]+"。\n"+
			"[与它初遇:spirit_companion choose "+species+"]\n\n";
	}
	result += "[查看共享宠物:pet]|[返回游戏:look]\n";
	return result;
}

private string render_spirit_catalog(mapping state)
{
	string result = "§5【本命灵伴图鉴】§r\n\n";
	result += "已相遇 "+sizeof((array)state["pets"])+"/"+
		sizeof((mapping)state["catalog"])+"\n\n";
	foreach(SPIRIT_COMPANIOND->query_spirit_companion_catalog();
	   string species;mapping info){
		mapping owned = ([]);
		foreach((array)state["pets"],mapping pet)
			if((string)pet["species"]==species){ owned=pet; break; }
		if(sizeof(owned))
			result += ((int)owned["active"] ? "★ " : "○ ")+
				(string)info["icon"]+(string)info["name"]+" Lv."+
				(int)owned["level"]+" · "+(string)info["combat"]+
				" [详情:spirit_companion detail "+
				(string)owned["id"]+"]\n";
		else
			result += "◇ 未相遇 · "+(string)info["icon"]+
				(string)info["name"]+" · 灵境寻踪可发现\n";
	}
	result += "\n每完成3次每日寻踪，稳定发现一位尚未收录的灵伴。\n";
	result += "[今日寻踪:spirit_companion explore]|[返回本命灵伴:spirit_companion]\n";
	return result;
}

private string render_spirit_detail(mapping state,string pet_id)
{
	mapping pet = find_spirit_pet(state,pet_id);
	if(!sizeof(pet))
		return "本命图鉴中没有这位灵伴。\n[返回本命灵伴:spirit_companion]\n";
	string result = "§5【"+(string)pet["icon"]+
		(string)pet["name"]+"】§r\n\n";
	result += (string)pet["temperament"]+"。\n";
	result += "协战："+(string)pet["skill"]+" · "+
		(string)pet["combat"]+"。\n";
	result += "成长：Lv."+(int)pet["level"]+"/"+
		SPIRIT_COMPANIOND->query_spirit_companion_level_max()+
		" · 亲密度 "+(int)pet["bond"]+"/100\n";
	if((int)pet["level"]<SPIRIT_COMPANIOND->query_spirit_companion_level_max())
		result += "历练："+(int)pet["xp"]+"/"+(int)pet["xp_need"]+"\n";
	result += "装备增益：伤害+"+(int)pet["attack_bonus"]+
		"% · 回复+"+(int)pet["support_bonus"]+"%\n";
	result += "装备槽：";
	foreach(SPIRIT_COMPANIOND->query_spirit_gear_slots();
	   string slot;mapping info)
		result += (string)info["name"]+"="+
			((string)(pet["equipment"][slot] || "")!="" ? "已装备" : "空")+" ";
	result += "\n\n";
	if(!(int)pet["active"])
		result += "[设为出战灵伴:spirit_companion active "+pet_id+"]\n";
	result += "[喂养5枚灵果:spirit_companion feed "+pet_id+"]|"+
		"[灵伴装备:spirit_companion gear "+pet_id+"]\n"+
		"[返回图鉴:spirit_companion catalog]|[返回本命灵伴:spirit_companion]\n";
	return result;
}

private string render_spirit_materials(mapping state)
{
	string result = "§5【本命灵伴材料匣】§r\n\n";
	foreach((mapping)state["material_names"];
	   string material;string name)
		result += name+"："+(int)state["materials"][material]+"\n";
	result += "\n同心灵果用于喂养；星砂碎片与月华灵丝用于打造。材料只属于当前角色，不进入人物背包，也不与共享宠物互通。\n";
	result += "[每日陪伴:spirit_companion interact]|"+
		"[灵境寻踪:spirit_companion explore]|"+
		"[装备工坊:spirit_companion gear]\n"+
		"[返回本命灵伴:spirit_companion]\n";
	return result;
}

private string render_spirit_gear(mapping state,void|string pet_id)
{
	string result = "§5【本命灵伴装备工坊】§r\n\n";
	if(!pet_id || pet_id=="")
		pet_id = (string)state["active_id"];
	mapping pet = find_spirit_pet(state,pet_id);
	result += "打造消耗5枚星砂碎片与2缕月华灵丝；装备只有伤害/回复小幅增益，不改人物属性。\n\n";
	foreach((mapping)state["gear_slots"];string slot;mapping info)
		result += (string)info["name"]+"："+(string)info["desc"]+
			" [打造:spirit_companion forge "+slot+"]\n";
	result += "\n装备栏：\n";
	if(!sizeof((array)state["gear_inventory"]))
		result += "（空）\n";
	foreach((array)state["gear_inventory"],mapping gear){
		int equipped = 0;
		foreach((array)state["pets"],mapping one)
			foreach((mapping)one["equipment"];string slot;mixed equipped_id)
				if((string)equipped_id==(string)gear["id"])
					equipped = 1;
		result += "• "+(string)gear["name"]+" · 伤害+"+
			(int)gear["attack_bonus"]+"% 回复+"+
			(int)gear["support_bonus"]+"% ";
		if(equipped)
			result += "（已穿戴）\n";
		else{
			if(sizeof(pet))
				result += "[给"+(string)pet["name"]+":spirit_companion equip "+
					pet_id+" "+(string)gear["id"]+"] ";
			result += "[分解:spirit_companion dismantle "+
				(string)gear["id"]+"]\n";
		}
	}
	if(sizeof(pet)){
		result += "\n当前查看："+(string)pet["name"]+"\n";
		foreach((mapping)state["gear_slots"];string slot;mapping info)
			if((string)(pet["equipment"][slot] || "")!="")
				result += "[卸下"+(string)info["name"]+
					":spirit_companion unequip "+pet_id+" "+slot+"]\n";
	}
	result += "\n[查看材料:spirit_companion materials]|"+
		"[返回本命灵伴:spirit_companion]\n";
	return result;
}

private string render_spirit_main(object me,mapping state)
{
	string source = SPIRIT_COMPANIOND->query_pet_battle_source(me);
	string result = "§5【本命灵伴】§r\n\n";
	result += "角色独立收集 · 陪伴成长 · 灵伴装备 · PVE/PVP协战\n";
	result += "与§g共享宠物·山海万灵谱§r完全分账；两套都可培养，但战斗只能携带一只。\n\n";
	if(!state["ok"])
		return result+(string)state["message"]+"\n[返回游戏:look]\n";
	if(!(int)state["claimed"])
		return result+render_spirit_starters();
	mapping active = find_spirit_pet(state,(string)state["active_id"]);
	result += "当前灵伴："+(string)active["icon"]+(string)active["name"]+
		" Lv."+(int)active["level"]+" · "+(string)active["combat"]+"\n";
	result += "当前战斗位："+(source=="personal" ?
		"§5本命灵伴§r" : "§g共享宠物§r")+"\n";
	result += "共享图鉴共鸣：伤害与回复 +"+
		(int)state["shared_resonance_bonus"]+"%（最高8%）\n";
	if(source!="personal")
		result += "[携带本命灵伴:spirit_companion carry]\n";
	else
		result += "★ 本命灵伴正在PVE/PVP中协战；PVP每场最多2次。\n";
	result += "\n图鉴："+sizeof((array)state["pets"])+"/"+
		sizeof((mapping)state["catalog"])+" · 寻踪进度 "+
		((int)state["explore_progress"]%3)+"/3\n";
	result += "同心灵果 "+(int)state["materials"]["companion_food"]+
		" · 星砂碎片 "+(int)state["materials"]["craft_shard"]+
		" · 月华灵丝 "+(int)state["materials"]["spirit_thread"]+"\n\n";
	if(!(int)state["daily_interact"])
		result += "[每日陪伴:spirit_companion interact] ";
	if(!(int)state["daily_explore"])
		result += "[灵境寻踪:spirit_companion explore]";
	result += "\n[灵伴图鉴:spirit_companion catalog]|"+
		"[当前详情:spirit_companion detail "+(string)active["id"]+"]|"+
		"[材料匣:spirit_companion materials]|"+
		"[装备工坊:spirit_companion gear]\n"+
		"[共享宠物:pet]|[返回游戏:look]\n";
	return result;
}

int main(string|zero arg)
{
	object me = this_player();
	array(string) parts = ({});
	string message = "";
	if(!me)
		return 0;
	if(arg && arg!="")
		parts = arg/" ";
	mapping state = SPIRIT_COMPANIOND->query_spirit_companion_state(me);
	if(sizeof(parts)==1 && parts[0]=="starter"){
		write(render_spirit_starters()); return 1;
	}
	if(sizeof(parts)==1 && parts[0]=="catalog" && state["ok"]){
		write(render_spirit_catalog(state)); return 1;
	}
	if(sizeof(parts)==1 && parts[0]=="materials" && state["ok"]){
		write(render_spirit_materials(state)); return 1;
	}
	if(sizeof(parts)>=1 && parts[0]=="gear" && state["ok"]){
		write(render_spirit_gear(state,
			sizeof(parts)>=2 ? parts[1] : "")); return 1;
	}
	if(sizeof(parts)==2 && parts[0]=="detail" && state["ok"]){
		write(render_spirit_detail(state,parts[1])); return 1;
	}
	if(sizeof(parts)==2 && parts[0]=="choose")
		message = (string)SPIRIT_COMPANIOND->choose_spirit_companion(
			me,parts[1])["message"];
	else if(sizeof(parts)==1 && parts[0]=="interact")
		message = (string)SPIRIT_COMPANIOND->interact_spirit_companion(me)["message"];
	else if(sizeof(parts)==1 && parts[0]=="explore")
		message = (string)SPIRIT_COMPANIOND->explore_spirit_companion(me)["message"];
	else if(sizeof(parts)==2 && parts[0]=="feed")
		message = (string)SPIRIT_COMPANIOND->feed_spirit_companion(
			me,parts[1])["message"];
	else if(sizeof(parts)==2 && parts[0]=="active")
		message = (string)SPIRIT_COMPANIOND->set_active_spirit_companion(
			me,parts[1])["message"];
	else if(sizeof(parts)==1 && parts[0]=="carry")
		message = (string)SPIRIT_COMPANIOND->set_pet_battle_source(
			me,"personal")["message"];
	else if(sizeof(parts)==2 && parts[0]=="forge")
		message = (string)SPIRIT_COMPANIOND->forge_spirit_gear(
			me,parts[1])["message"];
	else if(sizeof(parts)==3 && parts[0]=="equip")
		message = (string)SPIRIT_COMPANIOND->equip_spirit_gear(
			me,parts[1],parts[2])["message"];
	else if(sizeof(parts)==3 && parts[0]=="unequip")
		message = (string)SPIRIT_COMPANIOND->unequip_spirit_gear(
			me,parts[1],parts[2])["message"];
	else if(sizeof(parts)==2 && parts[0]=="dismantle")
		message = (string)SPIRIT_COMPANIOND->dismantle_spirit_gear(
			me,parts[1])["message"];
	else if(sizeof(parts))
		message = "未知的本命灵伴操作。";
	if(message!="")
		write(message+"\n\n");
	state = SPIRIT_COMPANIOND->query_spirit_companion_state(me);
	write(render_spirit_main(me,state));
	return 1;
}
