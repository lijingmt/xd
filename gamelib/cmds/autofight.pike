#include <command.h>
#include <gamelib/include/gamelib.h>

#define AUTOFIGHTD ((object)(ROOT "/gamelib/single/daemons/autofightd"))

private string format_time(int seconds)
{
	int hours;
	int minutes;
	if(seconds < 0)
		seconds = 0;
	hours = seconds/3600;
	minutes = (seconds%3600)/60;
	return hours+"小时"+minutes+"分钟";
}

private string view_recovery_items(object me, string kind)
{
	array(object) all;
	string out;
	mapping(string:int) shown;
	all = all_inventory(me);
	out = "";
	shown = ([]);
	foreach(all,object item){
		mapping supply;
		string item_name;
		int amount;
		if(!item || item->amount <= 0 || item->eat_flag != 1)
			continue;
		supply = item->add_supplay;
		if(!supply || !sizeof(supply))
			continue;
		item_name = item->query_name();
		if(shown[item_name])
			continue;
		amount = item->amount;
		if(kind == "life" && functionp(item->eat) &&
		   (int)supply["life_supply"] > 0){
			out += "["+item->query_name_cn()+":autofight food "+
				item_name+"]("+amount+"个，生命+"+
				(int)supply["life_supply"]+")\n";
			shown[item_name] = 1;
		}
		if(kind == "mana" && functionp(item->drink) &&
		   (int)supply["mofa_supply"] > 0){
			out += "["+item->query_name_cn()+":autofight water "+
				item_name+"]("+amount+"个，法力+"+
				(int)supply["mofa_supply"]+")\n";
			shown[item_name] = 1;
		}
	}
	if(out == "")
		out = kind == "life" ? "背包中没有可用的回血食物。\n" :
			"背包中没有可用的回蓝饮品。\n";
	return out;
}

private void show_settings(object me, string notice)
{
	string out;
	string food;
	string water;
	string skill;
	AUTOFIGHTD->initialize_player(me);
	food = (string)me["/plus/autofight_food"];
	water = (string)me["/plus/autofight_water"];
	skill = me->skills_enable;
	if(food == "" || food == "auto")
		food = "自动选择";
	if(water == "" || water == "auto")
		water = "自动选择";
	if(!skill || skill == "")
		skill = "未设置（使用普通攻击）";
	else if(MUD_SKILLSD[skill])
		skill = MUD_SKILLSD[skill]->query_name_cn();
	out = "【自动打怪／挂机】\n";
	if(notice && notice != "")
		out += notice+"\n\n";
	out += "状态："+(me->query_autofight()=="enable" ? "运行中" : "已停止")+"\n";
	out += "今日剩余："+format_time(AUTOFIGHTD->query_time_left(me))+"\n";
	out += "低血保护："+AUTOFIGHTD->query_hp_percent(me)+"％\n";
	out += "低法力补充："+AUTOFIGHTD->query_mana_percent(me)+"％\n";
	out += "回血食物："+food+"\n";
	out += "回蓝饮品："+water+"\n";
	out += "自动技能："+skill+"\n";
	out += "自动拾取："+(AUTOFIGHTD->query_loot_enabled(me) ? "开启" : "关闭")+"\n";
	out += "区域巡游："+(AUTOFIGHTD->query_roam_enabled(me) ? "开启" : "关闭")+"\n";
	out += "默认只刷当前地图；区域巡游只在同一地图区域内移动，并跳过友方、召唤兽、BOSS与高于自身2级的怪物。\n\n";
	if(me->query_autofight()=="enable")
		out += "[停止自动挂机:autofight stop]\n";
	else
		out += "[开始自动挂机:autofight start]\n";
	out += "[生命低于30％补血:autofight hp 30]|";
	out += "[生命低于50％补血:autofight hp 50]|";
	out += "[生命低于70％补血:autofight hp 70]\n";
	out += "[法力低于30％补充:autofight mana 30]|";
	out += "[法力低于50％补充:autofight mana 50]|";
	out += "[不自动补法力:autofight mana 0]\n";
	out += AUTOFIGHTD->query_loot_enabled(me) ?
		"[关闭自动拾取:autofight loot 0]\n" :
		"[开启自动拾取:autofight loot 1]\n";
	out += AUTOFIGHTD->query_roam_enabled(me) ?
		"[关闭区域巡游:autofight roam 0]\n" :
		"[开启区域巡游:autofight roam 1]\n";
	out += "\n回血食物（未指定时会自动选择）：\n";
	out += "[自动选择回血食物:autofight food auto]\n";
	out += view_recovery_items(me,"life");
	out += "\n回蓝饮品（未指定时会自动选择）：\n";
	out += "[自动选择回蓝饮品:autofight water auto]\n";
	out += view_recovery_items(me,"mana");
	out += "\n自动技能沿用技能页的“自动施放”设置。\n";
	out += "[前往技能设置:myskills]\n";
	out += "[返回游戏:look]\n";
	write(out);
}

int main(string|zero arg)
{
	object me;
	string action;
	string value;
	string reason;
	int number;
	me = this_player();
	if(!me)
		return 1;
	AUTOFIGHTD->initialize_player(me);
	action = "open";
	value = "";
	if(arg && arg != ""){
		if(sscanf(arg,"%s %s",action,value) != 2)
			action = arg;
	}
	if(action == "start" || action == "on"){
		reason = AUTOFIGHTD->query_start_block_reason(me);
		if(reason != ""){
			AUTOFIGHTD->stop_autofight(me);
			show_settings(me,"无法启动："+reason);
			return 1;
		}
		AUTOFIGHTD->start_autofight(me);
		show_settings(me,"自动挂机已启动。请保持游戏页面开启。");
		return 1;
	}
	if(action == "stop" || action == "off" || action == "close"){
		AUTOFIGHTD->stop_autofight(me);
		show_settings(me,"自动挂机已停止。");
		return 1;
	}
	if(action == "hp"){
		number = (int)value;
		if(number == 30 || number == 50 || number == 70)
			me["/plus/autofight_hp_percent"] = number;
		show_settings(me,"低血保护设置已更新。");
		return 1;
	}
	if(action == "mana"){
		number = (int)value;
		if(number == 0 || number == 30 || number == 50)
			me["/plus/autofight_mana_percent"] = number;
		show_settings(me,"法力补充设置已更新。");
		return 1;
	}
	if(action == "loot"){
		me["/plus/autofight_loot"] = value == "1" ? 1 : 0;
		show_settings(me,"自动拾取设置已更新。");
		return 1;
	}
	if(action == "roam"){
		me["/plus/autofight_roam"] = value == "1" ? 1 : 0;
		show_settings(me,value == "1" ?
			"区域巡游已开启，请选择适合当前等级的练级区域。" :
			"区域巡游已关闭，只会攻击当前地图刷新的怪物。");
		return 1;
	}
	if(action == "food"){
		me["/plus/autofight_food"] = value == "" ? "auto" : value;
		show_settings(me,"回血食物设置已更新。");
		return 1;
	}
	if(action == "water"){
		me["/plus/autofight_water"] = value == "" ? "auto" : value;
		show_settings(me,"回蓝饮品设置已更新。");
		return 1;
	}
	show_settings(me,"");
	return 1;
}
