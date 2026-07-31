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

private string vip_label(int level)
{
	return AUTOFIGHTD->query_vip_label(level);
}

private void show_vip_plan(object me)
{
	string out;
	int vip_level;
	vip_level = AUTOFIGHTD->query_vip_level(me);
	out = "【自动挂机·VIP权益总览】\n";
	out += "当前等级："+vip_label(vip_level)+"\n";
	out += "原则：核心挂机免费，VIP提升时长和清包效率；高等级包含低等级全部权益。\n\n";
	out += "普通玩家：每日8小时；自动战斗、智能寻路、补血补法、缺药休整、拾取、区域巡游、采药采矿及原料出售均可用。\n";
	out += vip_label(1)+"：每日10小时；普通白装自动出售，满包每次1件；非装备90％触发自动存仓／销毁，每次1组，处理药材和矿材。\n";
	out += vip_label(2)+"：每日12小时；可处理优良装备，装备90％触发每次2件，可设低3级保护；非装备85％触发每次2组，可自选处理类别。\n";
	out += vip_label(3)+"：每日14小时；可处理精制装备，装备80％触发每次4件，可取消等级差；非装备80％触发每次4组，可设置材料保留量。\n";
	out += vip_label(4)+"：每日16小时；装备70％触发每次8件；非装备每次8组，可自选70/80/90％触发线，并设置名称保护和优先处理。\n\n";
	out += "永久安全保护不因VIP改变：穿戴、任务、技能书、玉石、宝箱、补给、不可交易／丢弃／存储、唯一、特殊来源及高品质物品不会被误处理。\n\n";
	out += "[高级清包设置:autofight cleanup]\n";
	out += "[返回挂机设置:autofight open]\n";
	out += "[返回游戏:look]\n";
	write(out);
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
	int destroy_enabled;
	int store_enabled;
	int cleanup_trigger;
	int cleanup_keep;
	int warehouse_count;
	int warehouse_size;
	AUTOFIGHTD->initialize_player(me);
	mode = AUTOFIGHTD->query_auto_sell_mode(me);
	vip_level = AUTOFIGHTD->query_vip_level(me);
	level_gap = AUTOFIGHTD->query_auto_sell_level_gap(me);
	backpack_count = sizeof(all_inventory(me));
	backpack_size = me->query_beibao_size();
	mode_requirement =
		AUTOFIGHTD->query_auto_sell_mode_requirement(mode);
	destroy_enabled =
		AUTOFIGHTD->query_auto_destroy_non_equipment_enabled(me);
	store_enabled =
		AUTOFIGHTD->query_auto_store_non_equipment_enabled(me);
	cleanup_trigger = AUTOFIGHTD->query_auto_cleanup_trigger_percent(me);
	cleanup_keep = AUTOFIGHTD->query_auto_cleanup_keep(me);
	warehouse_count = me->packaged_items ? sizeof(me->packaged_items) : 0;
	warehouse_size = me->query_cangku_size();

	out = "【VIP挂机·智能清包】\n";
	if(notice && notice != "")
		out += notice+"\n\n";
	out += "当前VIP："+vip_label(vip_level)+"\n";
	out += "背包占用："+backpack_count+"/"+backpack_size+"\n";
	out += "当前策略："+AUTOFIGHTD->query_auto_sell_mode_cn(mode);
	if(mode != "off" &&
	   (mode_requirement > vip_level ||
	    AUTOFIGHTD->query_auto_sell_gap_requirement(level_gap) >
	    vip_level))
		out += "（VIP权限不足，已安全暂停）\n";
	else
		out += "\n";
	out += "装备出售触发：背包达到"+
		AUTOFIGHTD->query_auto_sell_trigger_percent(me)+"％\n";
	out += "装备单次处理："+AUTOFIGHTD->query_auto_sell_batch_size(me)+"件\n";
	out += "等级保护：只卖低于人物至少"+level_gap+"级的装备\n";
	out += "出售类别："+
		((int)me["/plus/autofight_sell_weapon"] == 1 ? "武器 " : "")+
		((int)me["/plus/autofight_sell_armor"] == 1 ? "防具 " : "")+
		((int)me["/plus/autofight_sell_accessory"] == 1 ?
			"首饰/饰物" : "")+"\n\n";

	out += vip_label(1)+"：装备满包触发，每次1件，可处理普通白装。\n";
	out += vip_label(2)+"：装备90％触发，每次2件，可选含优良装备和3级保护线。\n";
	out += vip_label(3)+"：装备80％触发，每次4件，可选含精制装备和不限等级差。\n";
	out += vip_label(4)+"：装备70％触发，每次8件，自动程度最高。\n\n";

	out += selected_prefix(mode == "off")+
		"[关闭智能清包:autofight sell off]\n";
	if(vip_level >= 1)
		out += selected_prefix(mode == "normal")+
			"[仅普通白装:autofight sell normal]\n";
	else
		out += "仅普通白装（"+vip_label(1)+"解锁）\n";
	if(vip_level >= 2)
		out += selected_prefix(mode == "excellent")+
			"[普通及优良装备:autofight sell excellent]\n";
	else
		out += "普通及优良装备（"+vip_label(2)+"解锁）\n";
	if(vip_level >= 3)
		out += selected_prefix(mode == "refined")+
			"[普通、优良及精制装备:autofight sell refined]\n";
	else
		out += "含精制装备（"+vip_label(3)+"解锁）\n";

	out += "\n等级保护选项：\n";
	if(vip_level >= 1)
		out += selected_prefix(level_gap == 5)+
			"[至少低5级才出售:autofight sellgap 5]\n";
	else
		out += "至少低5级才出售（"+vip_label(1)+"解锁）\n";
	if(vip_level >= 2)
		out += selected_prefix(level_gap == 3)+
			"[至少低3级才出售:autofight sellgap 3]\n";
	else
		out += "至少低3级才出售（"+vip_label(2)+"解锁）\n";
	if(vip_level >= 3)
		out += selected_prefix(level_gap == 0)+
			"[不限制等级差:autofight sellgap 0]\n";
	else
		out += "不限制等级差（"+vip_label(3)+"解锁）\n";

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
	out += "【VIP自动存仓／销毁】\n";
	out += "执行顺序：先存仓；仓库满、关闭存仓或物品不能处理时，才继续销毁和出售。\n";
	out += "仓库占用："+warehouse_count+"/"+warehouse_size+"\n";
	out += "当前触发线：背包"+cleanup_trigger+"％；单次存仓"+
		AUTOFIGHTD->query_auto_store_batch_size(me)+"组。\n";
	out += "自动存仓："+(store_enabled ? "开启" : "关闭")+"；自动销毁："+
		(destroy_enabled ? "开启" : "关闭")+"。\n";
	out += "处理类别：药材"+
		(AUTOFIGHTD->query_auto_cleanup_category_enabled(me,"herb") ?
		 "开启" : "保留")+"，矿材"+
		(AUTOFIGHTD->query_auto_cleanup_category_enabled(me,"mine") ?
		 "开启" : "保留")+"，其他普通物品"+
		(AUTOFIGHTD->query_auto_cleanup_category_enabled(me,"misc") ?
		 "开启" : "保留")+"。\n";
	if(vip_level >= 3)
		out += "材料保留量：每种保留"+cleanup_keep+"个，超出部分才处理。\n";
	out += vip_label(1)+"：90％触发，药材/矿材，每次存1组。\n";
	out += vip_label(2)+"：85％触发，每次存2组，可选择处理类别。\n";
	out += vip_label(3)+"：80％触发，每次存4组，可设置每种材料保留量。\n";
	out += vip_label(4)+"：70/80/90％可选，每次存8组，可设名称保护和优先处理。\n\n";
	if(vip_level < 1)
		out += "自动存仓和自动销毁（"+vip_label(1)+"解锁）；手动预览销毁仍免费。\n";
	else{
		out += store_enabled ?
			"✓ [关闭自动存仓:autofight storage 0]\n" :
			"[开启自动存仓:autofight storage 1]\n";
		out += destroy_enabled ?
			"✓ [关闭挂机销毁非装备:autofight destroy 0]\n" :
			"[开启挂机销毁非装备:autofight destroyconfirm]\n";
	}
	if(vip_level >= 2){
		out += "\n处理类别（"+vip_label(2)+"）：\n";
		out += AUTOFIGHTD->query_auto_cleanup_category_enabled(me,"herb") ?
			"✓ [药材：处理:autofight cleantype herb 0]\n" :
			"[药材：保留:autofight cleantype herb 1]\n";
		out += AUTOFIGHTD->query_auto_cleanup_category_enabled(me,"mine") ?
			"✓ [矿材：处理:autofight cleantype mine 0]\n" :
			"[矿材：保留:autofight cleantype mine 1]\n";
		out += AUTOFIGHTD->query_auto_cleanup_category_enabled(me,"misc") ?
			"✓ [其他普通物品：处理:autofight cleantype misc 0]\n" :
			"[其他普通物品：保留:autofight cleantype misc 1]\n";
	}
	if(vip_level >= 3){
		out += "\n每种材料保留量（"+vip_label(3)+"）：\n";
		out += selected_prefix(cleanup_keep == 0)+
			"[不保留:autofight cleankeep 0]|";
		out += selected_prefix(cleanup_keep == 50)+
			"[保留50:autofight cleankeep 50]|";
		out += selected_prefix(cleanup_keep == 100)+
			"[保留100:autofight cleankeep 100]|";
		out += selected_prefix(cleanup_keep == 300)+
			"[保留300:autofight cleankeep 300]\n";
	}
	if(vip_level >= 4){
		out += "\n触发线（"+vip_label(4)+"）：\n";
		out += selected_prefix(cleanup_trigger == 70)+
			"[70％:autofight cleantrigger 70]|";
		out += selected_prefix(cleanup_trigger == 80)+
			"[80％:autofight cleantrigger 80]|";
		out += selected_prefix(cleanup_trigger == 90)+
			"[90％:autofight cleantrigger 90]\n";
		out += "[设置名称保护／优先处理:autofight cleanlists]\n";
	}
	out += "\n安全规则永久保留：全部装备、任务/VIP物品、技能书、玉石、宝箱、丹药、食物饮品、不可丢弃/交易/存储物品、唯一物品、特殊来源和玩家标记物品。\n";
	out += "[预览并一键销毁（免费）:cleanup_non_equipment]\n\n";
	out += "[返回挂机设置:autofight open]\n";
	out += "[返回游戏:look]\n";
	write(out);
}

private void show_destroy_confirm(object me)
{
	string out;
	array(object) candidates;
	int object_count;
	int item_count;
	if(AUTOFIGHTD->query_vip_level(me) < 1){
		out = "【挂机销毁非装备】\n";
		out += "自动销毁由"+vip_label(1)+"解锁；普通玩家仍可免费手动预览并确认销毁。\n\n";
		out += "[预览并一键销毁:cleanup_non_equipment]\n";
		out += "[返回清包设置:autofight cleanup]\n";
		write(out);
		return;
	}
	candidates = AUTOFIGHTD->query_auto_cleanup_candidates(me);
	foreach(candidates,object item){
		object_count++;
		item_count += AUTOFIGHTD->query_auto_cleanup_process_amount(me,item);
	}
	out = "【确认开启·挂机销毁非装备】\n";
	out += "开启后，挂机脱离战斗且背包达到"+
		AUTOFIGHTD->query_auto_cleanup_trigger_percent(me)+
		"％时，会自动销毁符合当前VIP规则的非装备物品。\n";
	out += "当前按规则可销毁："+object_count+"组，共"+item_count+"个。\n";
	out += "装备、任务物品、技能书、玉石、宝箱、丹药、食物饮品和受限制物品都会保留。\n";
	out += "若同时开启自动存仓，将始终先存仓，仓库无法继续存放时才销毁。\n";
	out += "销毁不会获得金币，并会写入审计日志。\n\n";
	out += "[确认开启:autofight destroy 1]\n";
	out += "[先预览物品:cleanup_non_equipment]\n";
	out += "[取消:autofight cleanup]\n";
	write(out);
}

private void show_cleanup_lists(object me,string notice)
{
	string out;
	array(string) protect_names;
	array(string) force_names;
	mapping(string:int) shown;
	array(object) candidates;
	int shown_count;
	if(AUTOFIGHTD->query_vip_level(me) < 4){
		show_cleanup_settings(me,
			"名称保护和优先处理由"+vip_label(4)+"解锁。");
		return;
	}
	protect_names = AUTOFIGHTD->query_auto_cleanup_protect_names(me);
	force_names = AUTOFIGHTD->query_auto_cleanup_force_names(me);
	shown = ([]);
	candidates = AUTOFIGHTD->query_non_equipment_destroy_candidates(me);
	out = "【"+vip_label(4)+"·名称保护／优先处理】\n";
	if(notice && notice != "")
		out += notice+"\n\n";
	out += "保护名单（"+sizeof(protect_names)+"/20）："+
		(sizeof(protect_names) ? protect_names*"、" : "无")+"\n";
	out += "优先处理（"+sizeof(force_names)+"/20）："+
		(sizeof(force_names) ? force_names*"、" : "无")+"\n";
	out += "优先处理可越过类别开关，但不能越过永久安全保护和材料保留量。\n\n";
	foreach(candidates,object item){
		string item_name;
		string mode;
		if(shown_count >= 20)
			break;
		item_name = item->query_name();
		if(shown[item_name])
			continue;
		shown[item_name] = 1;
		shown_count++;
		mode = AUTOFIGHTD->query_auto_cleanup_name_mode(me,item_name);
		out += item->query_name_cn()+"（"+
			(mode == "protect" ? "已保护" :
			 mode == "force" ? "优先处理" : "默认规则")+"）\n";
		out += "[保护:autofight cleanname protect "+item_name+"]|";
		out += "[优先处理:autofight cleanname force "+item_name+"]|";
		out += "[恢复默认:autofight cleanname normal "+item_name+"]\n";
	}
	if(!shown_count)
		out += "背包中暂无可配置的普通非装备物品。\n";
	out += "\n[返回清包设置:autofight cleanup]\n";
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
	string gather_mode;
	int material_keep;
	AUTOFIGHTD->initialize_player(me);
	food = (string)me["/plus/autofight_food"];
	water = (string)me["/plus/autofight_water"];
	food_auto_prefix = "";
	water_auto_prefix = "";
	skill = me->skills_enable;
	daily_seconds = AUTOFIGHTD->query_daily_seconds_for(me);
	vip_level = AUTOFIGHTD->query_vip_level(me);
	gather_mode = AUTOFIGHTD->query_gather_mode(me);
	material_keep = AUTOFIGHTD->query_material_keep(me);
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
		out += "（"+vip_label(vip_level)+"，每级增加2小时）\n";
	else
		out += "（普通玩家；VIP每级增加2小时，"+
			vip_label(4)+"最高16小时）\n";
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
	out += "挂机销毁非装备："+
		(AUTOFIGHTD->query_auto_destroy_non_equipment_enabled(me) ?
		 "开启" : "关闭")+"\n";
	out += "挂机自动存仓："+
		(AUTOFIGHTD->query_auto_store_non_equipment_enabled(me) ?
		 "开启" : "关闭")+"\n";
	out += "区域巡游："+(AUTOFIGHTD->query_roam_enabled(me) ? "开启" : "关闭")+"\n";
	out += "随路自动采集："+
		AUTOFIGHTD->query_gather_mode_cn(gather_mode)+"\n";
	out += "采集原料自动出售："+(material_keep < 0 ? "关闭" :
		"每种保留"+material_keep+"个")+"\n";
	out += "智能寻路按真实怪物等级选择练级区，并在区内逐图搜索；50至69级使用固定成长区，70级起使用动态同级怪。\n";
	out += "开启采集后会优先采集沿途符合熟练度的药草和矿脉；采集原料按9999个一组堆叠，可按保留量自动出售。\n";
	out += "智能模式优先攻击同级附近、最高不超过自身1级的普通怪；缺药时会脱战、休息并返回练级区。副本、家园和城战地图不会自动传送。\n\n";
	if(me->query_autofight()=="enable")
		out += "[停止自动挂机:autofight stop]\n";
	else
		out += "[开始自动挂机:autofight start]\n";
	out += "[查看VIP挂机分级:autofight vip]\n";
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
	out += "[预览并一键销毁非装备:cleanup_non_equipment]\n";
	out += "\n采药采矿设置：\n";
	out += selected_prefix(gather_mode == "off")+
		"[关闭自动采集:autofight gather off]|";
	out += selected_prefix(gather_mode == "herb")+
		"[只采药:autofight gather herb]|";
	out += selected_prefix(gather_mode == "mine")+
		"[只采矿:autofight gather mine]\n";
	out += selected_prefix(gather_mode == "both")+
		"[采药和采矿:autofight gather both]\n";
	out += selected_prefix(material_keep < 0)+
		"[不自动卖原料:autofight materialkeep -1]|";
	out += selected_prefix(material_keep == 500)+
		"[每种保留500:autofight materialkeep 500]|";
	out += selected_prefix(material_keep == 300)+
		"[每种保留300:autofight materialkeep 300]\n";
	out += selected_prefix(material_keep == 100)+
		"[每种保留100:autofight materialkeep 100]|";
	out += selected_prefix(material_keep == 0)+
		"[采到即卖:autofight materialkeep 0]\n";
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
	if(action == "gather"){
		if(value != "off" && value != "mine" &&
		   value != "herb" && value != "both"){
			show_settings(me,"没有这个自动采集选项。");
			return 1;
		}
		me["/plus/autofight_gather_mode"] = value;
		show_settings(me,"随路自动采集设置已更新。");
		return 1;
	}
	if(action == "materialkeep"){
		number = (int)value;
		if(value == "" ||
		   (number != -1 && number != 0 && number != 100 &&
		    number != 300 && number != 500)){
			show_settings(me,"原料保留量选项无效。");
			return 1;
		}
		me["/plus/autofight_material_keep"] = number;
		show_settings(me,number < 0 ? "采集原料自动出售已关闭。" :
			"采集原料保留量已更新，超出部分会按商店价格出售。");
		return 1;
	}
	if(action == "cleanup"){
		show_cleanup_settings(me,"");
		return 1;
	}
	if(action == "vip"){
		show_vip_plan(me);
		return 1;
	}
	if(action == "destroyconfirm"){
		show_destroy_confirm(me);
		return 1;
	}
	if(action == "destroy"){
		if(value != "0" && value != "1"){
			show_cleanup_settings(me,"挂机销毁选项无效。");
			return 1;
		}
		if(value == "1" && AUTOFIGHTD->query_vip_level(me) < 1){
			show_cleanup_settings(me,
				"自动销毁由"+vip_label(1)+
				"解锁；手动预览销毁仍免费。");
			return 1;
		}
		me["/plus/autofight_destroy_non_equipment"] =
			value == "1" ? 1 : 0;
		show_cleanup_settings(me,value == "1" ?
			"挂机销毁非装备已开启；只在脱离战斗后执行。" :
			"挂机销毁非装备已关闭。");
		return 1;
	}
	if(action == "storage"){
		if(value != "0" && value != "1"){
			show_cleanup_settings(me,"自动存仓选项无效。");
			return 1;
		}
		if(value == "1" && AUTOFIGHTD->query_vip_level(me) < 1){
			show_cleanup_settings(me,
				"自动存仓由"+vip_label(1)+"解锁。");
			return 1;
		}
		me["/plus/autofight_store_non_equipment"] =
			value == "1" ? 1 : 0;
		show_cleanup_settings(me,value == "1" ?
			"自动存仓已开启；挂机会优先存仓，再执行销毁或出售。" :
			"自动存仓已关闭。已有仓库物品不受影响。");
		return 1;
	}
	if(action == "cleantype"){
		category = "";
		enabled_text = "";
		if(sscanf(value,"%s %s",category,enabled_text) != 2 ||
		   (enabled_text != "0" && enabled_text != "1") ||
		   (category != "herb" && category != "mine" &&
		    category != "misc")){
			show_cleanup_settings(me,"非装备处理类别选项无效。");
			return 1;
		}
		if(AUTOFIGHTD->query_vip_level(me) < 2){
			show_cleanup_settings(me,
				"自选处理类别由"+vip_label(2)+"解锁。");
			return 1;
		}
		number = enabled_text == "1" ? 1 : 0;
		if(category == "herb")
			me["/plus/autofight_cleanup_herb"] = number;
		else if(category == "mine")
			me["/plus/autofight_cleanup_mine"] = number;
		else
			me["/plus/autofight_cleanup_misc"] = number;
		show_cleanup_settings(me,"非装备处理类别已更新。");
		return 1;
	}
	if(action == "cleankeep"){
		number = (int)value;
		if(AUTOFIGHTD->query_vip_level(me) < 3){
			show_cleanup_settings(me,
				"材料保留量由"+vip_label(3)+"解锁。");
			return 1;
		}
		if(value == "" ||
		   (number != 0 && number != 50 && number != 100 &&
		    number != 300)){
			show_cleanup_settings(me,"材料保留量选项无效。");
			return 1;
		}
		me["/plus/autofight_cleanup_keep"] = number;
		show_cleanup_settings(me,"自动存仓／销毁的材料保留量已更新。");
		return 1;
	}
	if(action == "cleantrigger"){
		number = (int)value;
		if(AUTOFIGHTD->query_vip_level(me) < 4){
			show_cleanup_settings(me,
				"自选背包触发线由"+vip_label(4)+"解锁。");
			return 1;
		}
		if(number != 70 && number != 80 && number != 90){
			show_cleanup_settings(me,"背包触发线选项无效。");
			return 1;
		}
		me["/plus/autofight_cleanup_trigger"] = number;
		show_cleanup_settings(me,"自动存仓／销毁的背包触发线已更新。");
		return 1;
	}
	if(action == "cleanlists"){
		show_cleanup_lists(me,"");
		return 1;
	}
	if(action == "cleanname"){
		string item_mode;
		string item_name;
		object|zero selected_item;
		item_mode = "";
		item_name = "";
		if(sscanf(value,"%s %s",item_mode,item_name) != 2 ||
		   (item_mode != "normal" && item_mode != "protect" &&
		    item_mode != "force")){
			show_cleanup_lists(me,"名称规则选项无效。");
			return 1;
		}
		if(AUTOFIGHTD->query_vip_level(me) < 4){
			show_cleanup_settings(me,
				"名称保护和优先处理由"+vip_label(4)+"解锁。");
			return 1;
		}
		selected_item = present(item_name,me);
		if(item_mode != "normal" &&
		   (!selected_item ||
		    AUTOFIGHTD->query_non_equipment_destroy_reject_reason(
			me,selected_item) != "")){
			show_cleanup_lists(me,"只能设置背包内符合永久安全规则的普通物品。");
			return 1;
		}
		if(!AUTOFIGHTD->set_auto_cleanup_name_mode(
		   me,item_name,item_mode)){
			show_cleanup_lists(me,"名称规则保存失败，名单最多20项。");
			return 1;
		}
		show_cleanup_lists(me,"名称规则已更新。");
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
				vip_label(1)+"起可使用智能清包，当前设置没有改变。");
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
