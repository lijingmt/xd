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

string view_recovery_items(object me, string kind)
{
	array(object) all;
	string out;
	string selected;
	mapping(string:int) shown;
	all = all_inventory(me);
	out = "";
	selected = (string)me["/plus/autofight_water"];
	if(kind == "life")
		selected = (string)me["/plus/autofight_food"];
	shown = ([]);
	foreach(all,object item){
		mapping supply;
		string item_name;
		string selected_prefix;
		int amount;
		if(!item || item->amount <= 0 || item->eat_flag != 1)
			continue;
		supply = item->add_supplay;
		if(!supply || !sizeof(supply))
			continue;
		item_name = item->query_name();
		if(shown[item_name])
			continue;
		selected_prefix = "";
		if(selected == item_name)
			selected_prefix = "✓ 已选择 ";
		amount = item->amount;
		if(kind == "life" && functionp(item->eat) &&
		   (int)supply["life_supply"] > 0){
			out += selected_prefix+"["+
				item->query_name_cn()+":autofight food "+
				item_name+"]("+amount+"个，生命+"+
				(int)supply["life_supply"]+")\n";
			shown[item_name] = 1;
		}
		if(kind == "mana" && functionp(item->drink) &&
		   (int)supply["mofa_supply"] > 0){
			out += selected_prefix+"["+
				item->query_name_cn()+":autofight water "+
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

private string selected_prefix(int selected)
{
	return selected ? "✓ 已选择 " : "";
}

private void show_cleanup_settings(object me,string notice)
{
	string out;
	string mode;
	int vip_level;
	int level_gap;
	int backpack_count;
	int backpack_size;
	int mode_requirement;
	AUTOFIGHTD->initialize_player(me);
	mode = AUTOFIGHTD->query_auto_sell_mode(me);
	vip_level = AUTOFIGHTD->query_vip_level(me);
	level_gap = AUTOFIGHTD->query_auto_sell_level_gap(me);
	backpack_count = sizeof(all_inventory(me));
	backpack_size = me->query_beibao_size();
	mode_requirement =
		AUTOFIGHTD->query_auto_sell_mode_requirement(mode);

	out = "【VIP挂机·智能清包】\n";
	if(notice && notice != "")
		out += notice+"\n\n";
	out += "当前VIP："+(vip_level > 0 ? "VIP"+vip_level : "普通玩家")+"\n";
	out += "背包占用："+backpack_count+"/"+backpack_size+"\n";
	out += "当前策略："+AUTOFIGHTD->query_auto_sell_mode_cn(mode);
	if(mode != "off" &&
	   (mode_requirement > vip_level ||
	    AUTOFIGHTD->query_auto_sell_gap_requirement(level_gap) >
	    vip_level))
		out += "（VIP权限不足，已安全暂停）\n";
	else
		out += "\n";
	out += "自动触发：背包达到"+
		AUTOFIGHTD->query_auto_sell_trigger_percent(me)+"％\n";
	out += "单次处理："+AUTOFIGHTD->query_auto_sell_batch_size(me)+"件\n";
	out += "等级保护：只卖低于人物至少"+level_gap+"级的装备\n";
	out += "出售类别："+
		((int)me["/plus/autofight_sell_weapon"] == 1 ? "武器 " : "")+
		((int)me["/plus/autofight_sell_armor"] == 1 ? "防具 " : "")+
		((int)me["/plus/autofight_sell_accessory"] == 1 ?
			"首饰/饰物" : "")+"\n\n";

	out += "VIP1：满包触发，每次1件，可处理普通白装。\n";
	out += "VIP2：90％触发，每次2件，可选含优良装备和3级保护线。\n";
	out += "VIP3：80％触发，每次4件，可选含精制装备和不限等级差。\n";
	out += "VIP4：70％触发，每次8件，自动程度最高。\n\n";

	out += selected_prefix(mode == "off")+
		"[关闭智能清包:autofight sell off]\n";
	if(vip_level >= 1)
		out += selected_prefix(mode == "normal")+
			"[仅普通白装:autofight sell normal]\n";
	else
		out += "仅普通白装（VIP1解锁）\n";
	if(vip_level >= 2)
		out += selected_prefix(mode == "excellent")+
			"[普通及优良装备:autofight sell excellent]\n";
	else
		out += "普通及优良装备（VIP2解锁）\n";
	if(vip_level >= 3)
		out += selected_prefix(mode == "refined")+
			"[普通、优良及精制装备:autofight sell refined]\n";
	else
		out += "含精制装备（VIP3解锁）\n";

	out += "\n等级保护选项：\n";
	if(vip_level >= 1)
		out += selected_prefix(level_gap == 5)+
			"[至少低5级才出售:autofight sellgap 5]\n";
	else
		out += "至少低5级才出售（VIP1解锁）\n";
	if(vip_level >= 2)
		out += selected_prefix(level_gap == 3)+
			"[至少低3级才出售:autofight sellgap 3]\n";
	else
		out += "至少低3级才出售（VIP2解锁）\n";
	if(vip_level >= 3)
		out += selected_prefix(level_gap == 0)+
			"[不限制等级差:autofight sellgap 0]\n";
	else
		out += "不限制等级差（VIP3解锁）\n";

	out += "\n装备类别选项：\n";
	out += (int)me["/plus/autofight_sell_weapon"] == 1 ?
		"✓ [武器：出售:autofight selltype weapon 0]\n" :
		"[武器：保留:autofight selltype weapon 1]\n";
	out += (int)me["/plus/autofight_sell_armor"] == 1 ?
		"✓ [防具：出售:autofight selltype armor 0]\n" :
		"[防具：保留:autofight selltype armor 1]\n";
	out += (int)me["/plus/autofight_sell_accessory"] == 1 ?
		"✓ [首饰/饰物：出售:autofight selltype accessory 0]\n" :
		"[首饰/饰物：保留:autofight selltype accessory 1]\n";

	out += "\n永久保护：穿戴中、任务、不可交易、不可丢弃、唯一、特殊来源、玩家标记、无等级需求、已洗炼、已镶宝石、锻造/融合，以及神炼以上装备。\n";
	out += "自动出售会按普通商店价格结算，并写入独立审计日志。\n\n";
	out += "[返回挂机设置:autofight open]\n";
	out += "[返回游戏:look]\n";
	write(out);
}

private void show_settings(object me, string notice)
{
	string out;
	string food;
	string water;
	string skill;
	string food_auto_prefix;
	string water_auto_prefix;
	mapping route;
	int daily_seconds;
	int vip_level;
	AUTOFIGHTD->initialize_player(me);
	food = (string)me["/plus/autofight_food"];
	water = (string)me["/plus/autofight_water"];
	food_auto_prefix = "";
	water_auto_prefix = "";
	skill = me->skills_enable;
	daily_seconds = AUTOFIGHTD->query_daily_seconds_for(me);
	vip_level = AUTOFIGHTD->query_vip_level(me);
	route = AUTOFIGHTD->query_training_route(me);
	if(food == "" || food == "auto"){
		food = "自动选择";
		food_auto_prefix = "✓ 已选择 ";
	}
	if(water == "" || water == "auto"){
		water = "自动选择";
		water_auto_prefix = "✓ 已选择 ";
	}
	if(!skill || skill == "")
		skill = "未设置（使用普通攻击）";
	else if(MUD_SKILLSD[skill])
		skill = MUD_SKILLSD[skill]->query_name_cn();
	out = "【自动打怪／挂机】\n";
	if(notice && notice != "")
		out += notice+"\n\n";
	out += "状态："+(me->query_autofight()=="enable" ? "运行中" : "已停止")+"\n";
	out += "今日剩余："+format_time(AUTOFIGHTD->query_time_left(me))+"\n";
	out += "每日额度："+format_time(daily_seconds);
	if(vip_level > 0)
		out += "（VIP"+vip_level+"，每级增加2小时）\n";
	else
		out += "（普通玩家；VIP每级增加2小时，VIP4最高16小时）\n";
	out += "低血保护："+AUTOFIGHTD->query_hp_percent(me)+"％\n";
	out += "低法力补充："+AUTOFIGHTD->query_mana_percent(me)+"％\n";
	out += "回血食物："+food+"\n";
	out += "回蓝饮品："+water+"\n";
	out += "自动技能："+skill+"\n";
	out += "自动拾取："+(AUTOFIGHTD->query_loot_enabled(me) ? "开启" : "关闭")+"\n";
	out += "智能寻路："+(AUTOFIGHTD->query_smart_route_enabled(me) ?
		"开启（"+(string)route["name"]+"，约"+
		(int)route["level"]+"级怪）" : "关闭")+"\n";
	out += "缺药休整："+(AUTOFIGHTD->query_auto_rest_enabled(me) ?
		"开启" : "关闭")+"\n";
	out += "VIP智能清包："+
		AUTOFIGHTD->query_auto_sell_mode_cn(
			AUTOFIGHTD->query_auto_sell_mode(me))+"\n";
	out += "区域巡游："+(AUTOFIGHTD->query_roam_enabled(me) ? "开启" : "关闭")+"\n";
	out += "智能寻路按真实怪物等级选择练级区，并在区内逐图搜索；50级后使用动态同级怪。\n";
	out += "智能模式优先攻击同级附近、最高不超过自身1级的普通怪；缺药时会脱战、休息并返回练级区。副本、家园和城战地图不会自动传送。\n\n";
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
	out += AUTOFIGHTD->query_smart_route_enabled(me) ?
		"[关闭智能寻路:autofight route 0]\n" :
		"[开启智能寻路:autofight route 1]\n";
	out += AUTOFIGHTD->query_auto_rest_enabled(me) ?
		"[关闭缺药休整:autofight rest 0]\n" :
		"[开启缺药休整:autofight rest 1]\n";
	out += "[高级清包设置:autofight cleanup]\n";
	out += "\n回血食物（未指定时会自动选择）：\n";
	if(me->query_level()<=NEWBIED->query_newbie_supply_max_level())
		out += "[新手免费领红蓝药:get_free_yao]\n";
	out += food_auto_prefix+
		"[自动选择回血食物:autofight food auto]\n";
	out += view_recovery_items(me,"life");
	out += "\n回蓝饮品（未指定时会自动选择）：\n";
	out += water_auto_prefix+
		"[自动选择回蓝饮品:autofight water auto]\n";
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
	string category;
	string enabled_text;
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
	if(action == "route"){
		me["/plus/autofight_smart_route"] =
			value == "1" ? 1 : 0;
		show_settings(me,value == "1" ?
			"智能寻路已开启，将自动选择同级练级区。" :
			"智能寻路已关闭，将优先留在当前区域。");
		return 1;
	}
	if(action == "rest"){
		me["/plus/autofight_auto_rest"] =
			value == "1" ? 1 : 0;
		if(value != "1")
			AUTOFIGHTD->finish_auto_rest(me);
		show_settings(me,value == "1" ?
			"缺药休整已开启，补给不足时会前往安全地点恢复。" :
			"缺药休整已关闭；低血且无药时会安全停止挂机。");
		return 1;
	}
	if(action == "cleanup"){
		show_cleanup_settings(me,"");
		return 1;
	}
	if(action == "sell"){
		number = AUTOFIGHTD->query_auto_sell_mode_requirement(value);
		if(value != "off" && number == 0){
			show_cleanup_settings(me,"没有这个清包品质选项。");
			return 1;
		}
		if(number > AUTOFIGHTD->query_vip_level(me)){
			show_cleanup_settings(me,"VIP等级不足，当前设置没有改变。");
			return 1;
		}
		me["/plus/autofight_auto_sell_mode"] = value;
		show_cleanup_settings(me,value == "off" ?
			"智能清包已关闭。" :
			"智能清包策略已更新；只会在脱离战斗后处理装备。");
		return 1;
	}
	if(action == "sellgap"){
		number = (int)value;
		if((number != 0 && number != 3 && number != 5) ||
		   AUTOFIGHTD->query_auto_sell_gap_requirement(number) >
		   AUTOFIGHTD->query_vip_level(me)){
			show_cleanup_settings(me,
				"VIP等级不足或等级保护选项无效，当前设置没有改变。");
			return 1;
		}
		me["/plus/autofight_sell_level_gap"] = number;
		show_cleanup_settings(me,"等级保护设置已更新。");
		return 1;
	}
	if(action == "selltype"){
		category = "";
		enabled_text = "";
		if(sscanf(value,"%s %s",category,enabled_text) != 2 ||
		   (enabled_text != "0" && enabled_text != "1") ||
		   (category != "weapon" && category != "armor" &&
		    category != "accessory")){
			show_cleanup_settings(me,"装备类别选项无效。");
			return 1;
		}
		if(AUTOFIGHTD->query_vip_level(me) < 1){
			show_cleanup_settings(me,
				"VIP1起可使用智能清包，当前设置没有改变。");
			return 1;
		}
		number = enabled_text == "1" ? 1 : 0;
		if(category == "weapon")
			me["/plus/autofight_sell_weapon"] = number;
		else if(category == "armor")
			me["/plus/autofight_sell_armor"] = number;
		else
			me["/plus/autofight_sell_accessory"] = number;
		show_cleanup_settings(me,"装备类别设置已更新。");
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
