#include <command.h>
#include <gamelib/include/gamelib.h>

private string material_name(string material)
{
	if(material=="spirit_mark") return "灵印";
	if(material=="spirit_dew") return "灵露";
	if(material=="egg_fragment") return "灵卵残片";
	if(material=="skill_rune") return "灵纹符";
	if(material=="cosmetic_dust") return "月华尘";
	if(material=="bond_token") return "同心叶";
	return material;
}

private string pet_short_id(string pet_id)
{
	if(sizeof(pet_id)<=8)
		return pet_id;
	return pet_id[0..7];
}

private string render_starter(object me)
{
	string s = "【万灵初契】\n\n";
	s += "15级可从三位伙伴中任选一位；另外两位以后都可用灵印稳定兑换，选择不会造成不可逆的强弱差距。\n\n";
	foreach(PETD->query_starter_species(),string species){
		mapping info = PETD->query_pet_species(species);
		s += (string)info["icon"]+" §g"+(string)info["name"]+"§r · "+
			(string)info["role"]+"\n"+(string)info["origin"]+"\n"+
			"协战："+(string)info["skill"]+" " +
			"[选择它:pet choose "+species+"]\n\n";
	}
	s += "通用灵宠不占方士虎灵、鹤灵、龟灵的召唤数量，也不会参与三灵共鸣。\n";
	s += "[返回万灵谱:pet]|[返回游戏:look]\n";
	return s;
}

private string render_catalog(mapping state)
{
	string s = "【山海万灵图鉴】\n\n";
	multiset(string) owned = (<>);
	foreach((array)state["pets"],mapping pet)
		owned[(string)pet["species"]] = 1;
	mapping catalog = PETD->query_pet_catalog();
	foreach(sort(indices(catalog)),string species){
		mapping info = catalog[species];
		if((int)info["hidden"] && !owned[species])
			continue;
		s += owned[species] ? "✓ " : "○ ";
		s += (string)info["icon"]+(string)info["name"]+" · "+
			(string)info["role"]+" · "+
			PETD->query_pet_polarity_name(
				PETD->query_pet_species_polarity(species))+"属";
		if((int)info["boss"])
			s += " · 裂隙契约";
		else if((int)info["exchange"])
			s += " · 30灵印保底";
		s += " [小传:pet detail "+species+"]\n";
	}
	s += "\n收录 "+(int)state["collection_count"]+"/"+
		(int)state["catalog_total"]+"\n";
	s += "[返回万灵谱:pet]|[返回游戏:look]\n";
	return s;
}

private string vip_label(int level)
{
	string name = VIPD->get_vip_name(level);
	return "VIP"+level+"（"+(name && name!="" ? name : "会员")+"）";
}

private string pet_display_name(mapping pet,mapping info)
{
	if(mappingp(pet["fusion"]) && (string)pet["fusion"]["name"]!="")
		return (string)pet["fusion"]["name"];
	return (string)info["name"];
}

private string pet_rune_effect_label(mapping pet,mapping info)
{
	if(mappingp(pet["imprinted_skill"]))
		return (string)pet["imprinted_skill"]["effect"]=="heal" ?
			"拓印治疗" : "拓印攻击";
	if((string)info["role"]=="强攻" || (string)info["role"]=="迅捷")
		return "协战伤害";
	if((string)info["role"]=="灵息")
		return "法力回复";
	return "生命回复";
}

private string pet_gear_attributes(mapping gear)
{
	array(string) parts = ({});
	mapping attributes = mappingp(gear["attributes"]) ?
		gear["attributes"] : ([]);
	mapping(string:string) names = (["life":"生命","attack":"攻击",
		"defense":"防御","spirit":"灵息","speed":"迅捷"]);
	foreach(({"life","attack","defense","spirit","speed"}),
	   string attribute)
		if((int)attributes[attribute]>0)
			parts += ({names[attribute]+"+"+(int)attributes[attribute]+"%"});
	if((int)gear["xp_bonus_percent"]>0)
		parts += ({"历练+"+(int)gear["xp_bonus_percent"]+"%"});
	return sizeof(parts) ? parts*"、" : "无附加属性";
}

private string render_pet_gear(mapping gear_state,string pet_id)
{
	if(!gear_state["ok"])
		return (string)gear_state["message"]+"\n[返回万灵谱:pet]\n";
	mapping pet = gear_state["pet"];
	mapping slots = gear_state["slots"];
	string s = "§g【灵宠装备】§r\n\n";
	s += "兽铠、灵饰、灵核完全独立于人物背包，只增强当前灵宠；灵核还承载主人技能拓印。\n";
	s += "装备栏 "+sizeof((array)gear_state["gear_inventory"])+"/"+
		(int)gear_state["inventory_max"]+"\n\n";
	foreach(({"beast_armor","spirit_charm","spirit_core"}),string slot){
		mapping slot_info = slots[slot];
		mapping equipped = mappingp(pet["equipment_details"][slot]) ?
			pet["equipment_details"][slot] : ([]);
		s += (string)slot_info["icon"]+" "+(string)slot_info["name"]+"：";
		if(sizeof(equipped))
			s += (string)equipped["quality_name"]+"·"+
				(string)equipped["name"]+"（"+
				pet_gear_attributes(equipped)+"） "+
				"[卸下:pet gearunequip "+pet_id+" "+slot+"]\n";
		else
			s += "未穿戴\n";
		foreach((array)gear_state["gear_inventory"],mapping gear)
			if((string)gear["slot"]==slot &&
			   (string)(gear["equipped_by"] || "")=="")
				s += "  • "+(string)gear["quality_name"]+"·"+
					(string)gear["name"]+" Lv."+
					(int)gear["level_requirement"]+"（"+
					pet_gear_attributes(gear)+"） "+
					"[穿戴:pet gearequip "+pet_id+" "+
					(string)gear["id"]+"] "+
					"[分解:pet geardismantle "+pet_id+" "+
					(string)gear["id"]+"]\n";
	}
	s += "\n凝炼消耗5灵印，品质概率：凡品70% / 良品22% / 珍品7% / 神品1%。\n";
	s += "[凝炼兽铠:pet gearforge "+pet_id+" beast_armor] "+
		"[凝炼灵饰:pet gearforge "+pet_id+" spirit_charm] "+
		"[凝炼灵核:pet gearforge "+pet_id+" spirit_core]\n";
	s += "[学习主人技能:pet skill "+pet_id+"]|[返回宠物:pet detail "+
		(string)pet["species"]+"]|[返回万灵谱:pet]\n";
	return s;
}

private string render_pet_imprint(mapping state,string pet_id,object me)
{
	mapping pet = find_state_pet(state,pet_id);
	string s = "§m【灵技拓印】§r\n\n";
	if(!sizeof(pet))
		return "找不到这只灵宠。\n[返回万灵谱:pet]\n";
	s += "灵宠20级且穿戴灵核后，可学习当前角色真实掌握的主动攻击或治疗技能。\n";
	s += "拓印保留技能名称与战斗表现，但效果按灵宠属性、冷却和PVE/PVP安全上限结算，不复制人物技能数值。\n\n";
	if(mappingp(pet["imprinted_skill"])){
		mapping skill = pet["imprinted_skill"];
		s += "当前：拓印·"+(string)skill["name_cn"]+"（"+
			((string)skill["effect"]=="heal" ? "治疗" : "攻击")+
			"，习得时"+(int)skill["level"]+"级） "+
			"[遗忘:pet forget "+pet_id+"]\n\n";
	}
	else
		s += "当前：尚未拓印；第一次免费。\n\n";
	array candidates = PETD->query_pet_imprint_skill_candidates(me);
	if(!sizeof(candidates))
		s += "当前角色还没有可拓印的主动攻击或治疗技能。\n";
	else{
		s += "可学习：\n";
		foreach(candidates,mapping candidate)
			s += "• "+(string)candidate["name_cn"]+" Lv."+
				(int)candidate["level"]+" · "+
				((string)candidate["effect"]=="heal" ? "治疗" : "攻击")+
				" [拓印:pet imprint "+pet_id+" "+
				(string)candidate["name"]+"]\n";
	}
	s += "\n替换已有技能消耗1枚灵纹符；卸下灵核前必须先遗忘拓印。\n";
	s += "[灵宠装备:pet gear "+pet_id+"]|[返回万灵谱:pet]\n";
	return s;
}

private string render_detail(mapping state,string species,object me)
{
	mapping info = PETD->query_pet_species(species);
	string s;
	int owned = -1;
	for(int i=0;i<sizeof((array)state["pets"]);i++)
		if(state["pets"][i]["species"]==species){
			owned = i;
			break;
		}
	if(!sizeof(info))
		return "万灵谱中没有这种异兽。\n[返回图鉴:pet catalog]\n";
	if((int)info["hidden"] && owned<0)
		return "这页万灵谱仍被五采灵羽遮蔽，尚未与你建立灵契。\n[返回图鉴:pet catalog]\n";
	s = "【"+(string)info["icon"]+(string)info["name"]+"】\n\n";
	s += "灵属："+(string)info["family"]+" | 定位："+
		(string)info["role"]+" | 阴阳："+
		PETD->query_pet_polarity_name(
			PETD->query_pet_species_polarity(species))+"属\n";
	s += (string)info["origin"]+"\n\n";
	s += "战斗灵技："+(string)info["skill"]+
		"。PVE按冷却协战；人物PVP按战斗回合充能，每场最多触发2次，成长收益经过压缩且不能补刀。\n";
	s += "三套灵纹（名称是流派表现，三枚作为一套同步共鸣，不会分别叠加三次）：\n";
	for(int rune_set=0;rune_set<sizeof((array)info["skill_sets"]);
	   rune_set++){
		array skills = info["skill_sets"][rune_set];
		s += "• "+(skills*"、")+"\n  "+
			PETD->query_pet_rune_rhythm_description(rune_set,"灵技")+"\n";
	}
	if(owned>=0){
		mapping pet = state["pets"][owned];
		mapping attributes = pet["attributes"];
		int level_max = (int)pet["level_max"];
		int trained_level = (int)pet["trained_level"];
		s += "\n契名："+pet_display_name(pet,info)+"\n";
		s += "阴阳："+(string)pet["polarity_name"]+"属\n";
		if(mappingp(pet["fusion"])){
			mapping fusion = pet["fusion"];
			s += "融合："+(string)fusion["quality_name"]+" · 第"+
				(int)fusion["generation"]+"代 · 成长增益+"+
				(int)fusion["growth_bonus"]+"%\n";
			s += "灵脉："+((array)fusion["traits"]*"、")+"\n";
		}
		s += "已收录：Lv."+(int)pet["level"]+"/"+level_max+" · "+
			(int)pet["star"]+"星 · "+(string)pet["evolution_name"]+
			" · 羁绊"+(int)pet["bond"]+"/5\n";
		if((int)pet["level_limited"])
			s += "共享培养进度：Lv."+trained_level+
				"（已完整保留）；当前角色只按Lv."+
				(int)pet["level"]+"属性协战。\n";
		if(trained_level>=level_max)
			s += "战斗历练：已与当前人物等级同步；人物升级后继续成长，当前不囤积溢出历练。\n";
		else
			s += "战斗历练："+(int)pet["xp"]+"/"+
				(int)pet["xp_need"]+"（协战击败合适等级怪物会自动连续升级）\n";
		s += "灵宠战力："+(int)pet["power"]+" | 生命"+
			(int)attributes["life"]+" | 攻击"+(int)attributes["attack"]+
			" | 防御"+(int)attributes["defense"]+" | 灵息"+
			(int)attributes["spirit"]+" | 迅捷"+(int)attributes["speed"]+"\n";
		s += "PVE成长倍率："+(int)pet["growth_percent"]+
			"% | PVP压缩倍率："+(int)pet["pvp_growth_percent"]+
			"% | 编号"+pet_short_id((string)pet["id"])+"\n";
		s += "当前灵纹："+((array)pet["skills"]*"、")+"\n";
		s += "实际共鸣："+
			PETD->query_pet_rune_rhythm_description(
				(int)pet["skill_set"],pet_rune_effect_label(pet,info))+"\n";
		if(SPIRIT_COMPANIOND->query_pet_battle_source(me)!="shared")
			s += "§y注意：当前战斗位是本命灵伴，本共享宠物处于待命，灵技与灵纹不会触发；切回共享宠物后生效。§r\n"+
				"[立即携带共享宠物:pet carry]\n";
		if(mappingp(pet["fusion"]))
			s += "融合说明：三枚灵纹分别继承父系，但仍按上面的当前共鸣节奏作为一套结算；真实生效时战斗中会出现三纹共鸣提示。\n";
		if(species=="luanniao")
			s += "隐藏天赋：回生羽会在主人真正死亡时自动触发；灵医职业复苏优先，账号每日1次，复活后恢复15%生命与10%法力，切磋和自杀不消耗。\n";
		if(mappingp(pet["imprinted_skill"]))
			s += "拓印灵技："+(string)pet["imprinted_skill"]["name_cn"]+
				"（"+((string)pet["imprinted_skill"]["effect"]=="heal" ?
				"治疗" : "攻击")+"）\n";
		else
			s += "拓印灵技：未学习（灵宠20级开放）\n";
		s += "灵纹节奏："+((int)pet["skill_set"]==1 ?
			"轻灵（80%效果/24秒）" : ((int)pet["skill_set"]==2 ?
			"厚积（115%效果/36秒）" : "均衡（100%效果/30秒）"))+"\n";
		s += "灵纹符："+(int)state["materials"]["skill_rune"]+
			"枚（独立材料，不在人物背包；轮换消耗1枚）\n";
		s += "获取：每周平复3次万灵裂隙后，在『今日修行→本周目标』"+
			"三选一领取2枚。 [查看周目标:daily_cultivation] "+
			"[前往裂隙:wanling_rift]\n";
		s += "已收录外观："+((array)pet["variants"]*"、")+"\n";
		s += "[设为协战:pet active "+(string)pet["id"]+"] ";
		if(trained_level<level_max){
			s += "[灵露加速1级:pet level "+
				(string)pet["id"]+"]\n";
			if(VIPD->query_active_vip_level(me)>=2)
				s += "[灵露连续加速10级:pet level10 "+
					(string)pet["id"]+"]（"+vip_label(2)+"）\n";
			else
				s += "连续提升10级（"+vip_label(2)+"解锁）"+
					"[升级会员:vip_service_list]\n";
		}
		else
			s += "已达当前人物有效等级上限\n";
		s +=
			"[消耗残片升星:pet star "+(string)pet["id"]+"] "+
			"[深化羁绊:pet bond "+(string)pet["id"]+"]\n"+
			"[轮换灵纹:pet reset "+(string)pet["id"]+"]\n"+
			"[灵宠装备:pet gear "+(string)pet["id"]+"] "+
			"[学习主人技能:pet skill "+(string)pet["id"]+"]\n"+
			"[40月华尘解锁星辉异色:pet variant "+
			(string)pet["id"]+"]\n";
	}
	else if((int)info["exchange"])
		s += "\n[用30灵印稳定兑换:pet exchange "+species+"]\n";
	else
		s += "\n本灵契可由裂隙低概率完整灵卵取得，也可用60枚灵卵残片稳定孵化；异色只改变外观。\n"+
			"[60残片稳定孵化:pet hatch "+species+"]\n";
	s += "\n[返回图鉴:pet catalog]|[返回万灵谱:pet]\n";
	return s;
}

private string render_materials(mapping state)
{
	string s = "【万灵材料栏】\n\n";
	s += "这些材料不进入背包，不占格子，也不能被丢弃或卖错。\n\n";
	foreach(indices(state["materials"]),string material)
		s += "• "+material_name(material)+"："+
			(int)state["materials"][material]+"\n";
	s += "\n灵印可稳定换基础灵宠；灵卵残片既可用于1—10星成长，也可用60枚任选裂隙异兽稳定孵化；3/6/9星自动进化。灵纹符按顺序轮换协战节奏；40月华尘可保底解锁星辉异色。\n";
	s += "灵纹符获取：每周平复3次万灵裂隙后，在『今日修行→本周目标』三选一选择灵纹符，一次领取2枚；它保存在独立材料栏，不会出现在人物背包。\n";
	s += "[查看本周进度:daily_cultivation]|[组队挑战裂隙:wanling_rift]\n";
	s += "\n残片来源：每日寻迹稳定获得2枚；普通同级怪4%、副本怪12%、首领30%、副本首领50%概率获得1枚，战斗掉落按账号每日最多12枚；组队裂隙仍有最高综合效率、周奖励与完整灵卵保底。\n";
	s += "[可兑换灵宠:pet catalog]|[返回万灵谱:pet]\n";
	return s;
}

private string render_team(mapping state,object me)
{
	array team = state["duel_teams"][me->query_name()] || ({});
	string s = "【三宠论道编队】\n\n";
	s += "人物等级、装备、VIP和宠物培养数值全部标准化；不足三只时自动借用新手试炼灵宠。\n\n";
	for(int i=0;i<sizeof((array)state["pets"]);i++){
		mapping pet = state["pets"][i];
		mapping info = PETD->query_pet_species((string)pet["species"]);
		int selected = search(team,(string)pet["id"])!=-1;
		s += selected ? "✓ " : "○ ";
		s += (string)info["icon"]+pet_display_name(pet,info)+" "+
			(selected ? "[移出:pet teamtoggle " : "[加入:pet teamtoggle ")+
			(string)pet["id"]+"]\n";
	}
	s += "\n当前已选 "+sizeof(team)+"/3。\n";
	s += "[寻找论道对手:pet_duel list]|[返回万灵谱:pet]\n";
	return s;
}

private mapping find_state_pet(mapping state,string pet_id)
{
	foreach((array)state["pets"],mapping pet)
		if((string)pet["id"]==pet_id)
			return pet;
	return ([]);
}

private string render_fusion(mapping state,object me,string first_id,
	string second_id)
{
	string s = "§m【阴阳灵契合成】§r\n\n";
	s += "仅一阴一阳、不同种类的灵宠可以合成。成功时两只原宠合为一只随机契名、阴阳、品质、灵脉与属性结构的新宠，并继承双方最高等级、星级和羁绊；失败时原宠完整保留。\n\n";
	if(first_id==""){
		s += "第一步：选择第一只灵宠。\n";
		foreach((array)state["pets"],mapping pet){
			mapping info = PETD->query_pet_species((string)pet["species"]);
			if((int)info["hidden"])
				continue;
			s += "• "+(string)info["icon"]+pet_display_name(pet,info)+
				" · "+(string)pet["polarity_name"]+"属 · Lv."+
				(int)pet["level"]+"·"+(int)pet["star"]+"星 "+
				"[选择:pet fusion "+(string)pet["id"]+"]\n";
		}
	}
	else if(second_id==""){
		mapping first = find_state_pet(state,first_id);
		if(!sizeof(first))
			s += "第一只灵宠已经不存在，请重新选择。\n";
		else{
			mapping first_info = PETD->query_pet_species(
				(string)first["species"]);
			s += "已选："+(string)first_info["icon"]+
				pet_display_name(first,first_info)+"（"+
				(string)first["polarity_name"]+"属）\n\n";
			s += "第二步：选择相反阴阳的灵宠。\n";
			foreach((array)state["pets"],mapping pet){
				if((string)pet["id"]==first_id ||
				   (string)pet["polarity"]==(string)first["polarity"])
					continue;
				mapping info = PETD->query_pet_species(
					(string)pet["species"]);
				if((int)info["hidden"])
					continue;
				s += "• "+(string)info["icon"]+
					pet_display_name(pet,info)+" · "+
					(string)pet["polarity_name"]+"属 · Lv."+
					(int)pet["level"]+"·"+(int)pet["star"]+"星 "+
					"[选择:pet fusion "+first_id+" "+
					(string)pet["id"]+"]\n";
			}
		}
	}
	else{
		mapping preview = PETD->query_pet_fusion_preview(me,first_id,
			second_id);
		if(!preview["ok"])
			s += (string)preview["message"]+"\n";
		else{
			mapping first = preview["first"];
			mapping second = preview["second"];
			mapping first_info = PETD->query_pet_species(
				(string)first["species"]);
			mapping second_info = PETD->query_pet_species(
				(string)second["species"]);
			s += "合成双方："+(string)first_info["icon"]+
				pet_display_name(first,first_info)+"（"+
				(string)first["polarity_name"]+"） × "+
				(string)second_info["icon"]+
				pet_display_name(second,second_info)+"（"+
				(string)second["polarity_name"]+"）\n";
			s += "成功率："+(int)preview["success_chance"]+
				"% | 失败积累："+(int)preview["pity"]+"/5 | 新灵契：第"+
				(int)preview["generation"]+"代\n";
			s += "成功消耗10灵印；失败消耗"+
				(int)preview["failure_cost"]+"灵印且两只原宠不消失。";
			if(VIPD->query_active_vip_level(me)>=3)
				s += " VIP3（白金会员）失败保护已生效。";
			else
				s += " [VIP3失败返还一半灵印:vip_service_list]";
			s += "\n\n§y成功会把两只原宠不可逆地合为一只新宠。§r\n";
			s += "[确认阴阳合成:pet fuse "+first_id+" "+
				second_id+"]\n";
		}
	}
	s += "\n[重新选择:pet fusion]|[返回万灵谱:pet]\n";
	return s;
}

private string render_main(mapping state,object me)
{
	string character_id = me->query_name();
	string active_id = (string)(state["active"][character_id] || "");
	string active_name = "未设置";
	for(int i=0;i<sizeof((array)state["pets"]);i++)
		if(state["pets"][i]["id"]==active_id){
			mapping info = PETD->query_pet_species(
				(string)state["pets"][i]["species"]);
			active_name = (string)info["icon"]+
				pet_display_name(state["pets"][i],info)+
				"（Lv."+(int)state["pets"][i]["level"]+" · "+
				(int)state["pets"][i]["star"]+"星"+
				(string)state["pets"][i]["evolution_name"]+"）";
			break;
		}
	string boss_species = (string)state["weekly_boss"];
	mapping boss = PETD->query_pet_species(boss_species);
	mapping guidance = PETD->query_pet_growth_guidance(me);
	string s = "§g【共享宠物·山海万灵谱】§r\n\n";
	string battle_source = SPIRIT_COMPANIOND->query_pet_battle_source(me);
	s += "共享宠物收藏："+(int)state["collection_count"]+"/"+
		(int)state["catalog_total"]+" | 当前协战："+active_name+"\n";
	s += "当前战斗位："+(battle_source=="shared" ?
		"§g共享宠物§r" : "§5本命灵伴§r")+"\n";
	if(battle_source!="shared" && active_id!="")
		s += "[携带共享宠物:pet carry]\n";
	if(find_state_pet(state,active_id)["species"]=="luanniao")
		s += "回生羽："+((int)state["daily"]["owner_revive"] ?
			"今日已使用" : "今日可触发1次")+"\n";
	s += "出战灵宠会从合适等级的真实怪物获得历练并自动连续升级；灵露可用于加速培养。\n";
	s += "有效等级不超过当前人物Lv."+
		(int)state["level_max"]+"；共享高等级培养进度永久保留，低等级角色只临时按自身等级生效。\n";
	s += "本周裂隙："+(string)boss["icon"]+(string)boss["name"]+
		" | 周胜场 "+(int)state["weekly"]["rift_wins"]+"/3"+
		" | 完整灵卵保底 "+(int)state["rift_pity"]+"/30\n";
	s += "灵印："+(int)state["materials"]["spirit_mark"]+
		" | 灵露："+(int)state["materials"]["spirit_dew"]+
		" | 灵卵残片："+(int)state["materials"]["egg_fragment"]+"\n";
	s += "灵纹符："+(int)state["materials"]["skill_rune"]+
		"（本周裂隙3胜后可三选一领2枚） "+
		"[获取说明:pet materials]\n\n";
	s += "今日战斗残片："+(int)state["daily"]["pve_fragments"]+"/"+
		PETD->query_pet_pve_fragment_daily_cap()+
		"（普通怪、副本与首领均可获得）\n\n";
	if(guidance["ok"] && sizeof((array)guidance["suggestions"])){
		mapping next = guidance["suggestions"][0];
		s += "§y【成长助手·下一步】§r "+(string)next["title"]+"\n"+
			(string)next["detail"]+"\n["+(string)next["action_label"]+
			":"+(string)next["action_command"]+"]|"+
			"[查看完整建议:pet guide]\n\n";
	}
	if(sizeof((mapping)state["pending_rift_rewards"]))
		s += "★ 有"+sizeof((mapping)state["pending_rift_rewards"])+
			"份裂隙个人奖励等待领取（资格保留7天）。\n"+
			"[立即领取:wanling_rift claim]\n\n";
	if(!(int)state["starter_claimed"]){
		if(me->query_level()>=15)
			s += "★ 第一位万灵伙伴已经可以领取。\n[选择新手灵宠:pet starter]\n\n";
		else
			s += "○ 15级开放第一位万灵伙伴，当前"+me->query_level()+"级。\n\n";
	}
	if(sizeof((array)state["pets"])){
		s += "我的伙伴：\n";
		foreach((array)state["pets"],mapping pet){
			mapping info = PETD->query_pet_species((string)pet["species"]);
				s += ((string)pet["id"]==active_id ? "✓ " : "○ ")+
					(string)info["icon"]+pet_display_name(pet,info)+" "+
					"Lv."+(int)pet["level"]+"·"+(int)pet["star"]+
					"星"+(string)pet["evolution_name"]+"·战力"+
					(int)pet["power"]+"·羁绊"+(int)pet["bond"]+
					((int)pet["level_limited"] ? "·培养Lv."+
					(int)pet["trained_level"]+"已保留" : "")+
					" [详情:pet detail "+(string)pet["species"]+"]\n";
		}
		s += "[暂停当前协战:pet active none]\n\n";
	}
	s += "[单人每日寻迹:pet_hunt]|[今日修行:daily_cultivation]|[万灵裂隙:wanling_rift]\n";
	s += "[灵宠论道:pet_duel list]\n";
	s += "[完整图鉴:pet catalog]|[论道编队:pet team]|[独立材料栏:pet materials]\n";
	s += "[阴阳灵契合成:pet fusion]（失败保留原宠）\n";
	s += "[前往万灵台:wanling_rift gather]\n";
	s += "[本命灵伴:spirit_companion]（角色独立收集与培养）\n";
	s += "\n公平规则：宠物有效等级不超过当前人物等级；VIP只通过人物自身可达等级间接影响上限，不另外倍增宠物成长。PVE使用完整培养成长；人物PVP只保留20%额外成长、每场最多2次且不能补刀。三宠论道继续完全标准化。\n";
	if(me->query_profeId()=="fangshi")
		s += "方士说明：万灵伙伴不占虎灵、鹤灵、龟灵名额，不触发三灵共鸣。\n";
	s += "[返回游戏:look]\n";
	return s;
}

private string render_growth_guide(object me)
{
	mapping guidance = PETD->query_pet_growth_guidance(me);
	string s = "§y【万灵成长助手】§r\n\n";
	if(!guidance["ok"])
		return (string)guidance["message"]+"\n[返回万灵谱:pet]\n";
	s += "助手只读取当前账号状态，不会自动消耗材料；建议会随领取、出战、等级、装备、技能和日周进度实时变化。\n\n";
	for(int i=0;i<sizeof((array)guidance["suggestions"]);i++){
		mapping suggestion = guidance["suggestions"][i];
		s += (i==0 ? "★ 首要" : "○ 备选")+" · "+
			(string)suggestion["phase"]+"｜"+
			(string)suggestion["title"]+"\n"+
			(string)suggestion["detail"]+"\n";
		if((int)suggestion["target"]>1)
			s += "进度："+(int)suggestion["current"]+"/"+
				(int)suggestion["target"]+"\n";
		s += "["+(string)suggestion["action_label"]+":"+
			(string)suggestion["action_command"]+"]\n\n";
	}
	s += "[刷新建议:pet guide]|[返回万灵谱:pet]|[返回游戏:look]\n";
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	mapping state;
	array(string) parts;
	string message = "";
	string return_species = "";
	if(!me)
		return 0;
	state = PETD->query_pet_state(me);
	if(!state["ok"]){
		write((string)state["message"]+"\n[返回游戏:look]\n");
		return 1;
	}
	if(!arg || arg==""){
		write(render_main(state,me));
		return 1;
	}
	parts = arg/" ";
	if(parts[0]=="starter"){
		write(render_starter(me));
		return 1;
	}
	if(parts[0]=="catalog"){
		write(render_catalog(state));
		return 1;
	}
	if(parts[0]=="materials"){
		write(render_materials(state));
		return 1;
	}
	if(parts[0]=="guide"){
		write(render_growth_guide(me));
		return 1;
	}
	if(parts[0]=="team"){
		write(render_team(state,me));
		return 1;
	}
	if(parts[0]=="fusion"){
		write(render_fusion(state,me,
			sizeof(parts)>=2 ? parts[1] : "",
			sizeof(parts)>=3 ? parts[2] : ""));
		return 1;
	}
	if(parts[0]=="detail" && sizeof(parts)>=2){
		write(render_detail(state,parts[1],me));
		return 1;
	}
	if(parts[0]=="gear" && sizeof(parts)>=2){
		PETD->claim_pet_starter_gear(me,parts[1]);
		write(render_pet_gear(PETD->query_pet_equipment_state(me,
			parts[1]),parts[1]));
		return 1;
	}
	if(parts[0]=="skill" && sizeof(parts)>=2){
		write(render_pet_imprint(state,parts[1],me));
		return 1;
	}
	if(sizeof(parts)>=2){
		foreach((array)state["pets"],mapping pet)
			if((string)pet["id"]==parts[1]){
				return_species = (string)pet["species"];
				break;
			}
	}
	if(parts[0]=="choose" && sizeof(parts)>=2)
		message = (string)PETD->choose_starter_pet(me,parts[1])["message"];
	else if(parts[0]=="carry")
		message = (string)SPIRIT_COMPANIOND->set_pet_battle_source(
			me,"shared")["message"];
	else if(parts[0]=="active" && sizeof(parts)>=2)
		message = (string)PETD->set_active_pet(me,parts[1])["message"];
	else if(parts[0]=="level" && sizeof(parts)>=2)
		message = (string)PETD->train_pet_level(me,parts[1])["message"];
	else if(parts[0]=="level10" && sizeof(parts)>=2)
		message = (string)PETD->train_pet_levels(me,parts[1],10)["message"];
	else if(parts[0]=="star" && sizeof(parts)>=2)
		message = (string)PETD->upgrade_pet_star(me,parts[1])["message"];
	else if(parts[0]=="bond" && sizeof(parts)>=2)
		message = (string)PETD->deepen_pet_bond(me,parts[1])["message"];
	else if(parts[0]=="reset" && sizeof(parts)>=2)
		message = (string)PETD->reset_pet_skills(me,parts[1])["message"];
	else if(parts[0]=="exchange" && sizeof(parts)>=2)
		message = (string)PETD->exchange_pet(me,parts[1])["message"];
	else if(parts[0]=="hatch" && sizeof(parts)>=2)
		message = (string)PETD->hatch_pet_fragments(me,parts[1])["message"];
	else if(parts[0]=="variant" && sizeof(parts)>=2)
		message = (string)PETD->unlock_pet_dust_variant(me,parts[1])["message"];
	else if(parts[0]=="gearequip" && sizeof(parts)>=3)
		message = (string)PETD->equip_pet_gear(me,parts[1],parts[2])["message"];
	else if(parts[0]=="gearunequip" && sizeof(parts)>=3)
		message = (string)PETD->unequip_pet_gear(me,parts[1],parts[2])["message"];
	else if(parts[0]=="gearforge" && sizeof(parts)>=3)
		message = (string)PETD->forge_pet_gear(me,parts[2])["message"];
	else if(parts[0]=="geardismantle" && sizeof(parts)>=3)
		message = (string)PETD->dismantle_pet_gear(me,parts[2])["message"];
	else if(parts[0]=="imprint" && sizeof(parts)>=3)
		message = (string)PETD->imprint_pet_skill(me,parts[1],parts[2])["message"];
	else if(parts[0]=="forget" && sizeof(parts)>=2)
		message = (string)PETD->forget_pet_imprinted_skill(me,parts[1])["message"];
	else if(parts[0]=="fuse" && sizeof(parts)>=3){
		mapping fusion_result = PETD->fuse_pets(me,parts[1],parts[2]);
		write((string)fusion_result["message"]+
			"\n[继续阴阳合成:pet fusion]|[返回万灵谱:pet]|[返回游戏:look]\n");
		return 1;
	}
	else if(parts[0]=="teamtoggle" && sizeof(parts)>=2){
		array(string) team = state["duel_teams"][me->query_name()] || ({});
		int index = search(team,parts[1]);
		if(index!=-1)
			team -= ({parts[1]});
		else if(sizeof(team)<3)
			team += ({parts[1]});
		else{
			write("论道编队已经有3只，请先移出一只。\n[返回编队:pet team]\n");
			return 1;
		}
		message = (string)PETD->set_pet_duel_team(me,team)["message"];
		write(message+"\n[返回编队:pet team]\n");
		return 1;
	}
	else{
		write("未知的万灵操作。\n[返回万灵谱:pet]\n");
		return 1;
	}
	write(message+"\n");
	if(parts[0]=="reset")
		write("[查看灵纹符获取:daily_cultivation]|"+
			"[组队挑战万灵裂隙:wanling_rift]|"+
			"[查看独立材料栏:pet materials]\n");
	if(search(({"gearequip","gearunequip","gearforge","geardismantle"}),
	   parts[0])!=-1 && sizeof(parts)>=2){
		write("[继续整理灵宠装备:pet gear "+parts[1]+"]|"+
			"[返回万灵谱:pet]|[返回游戏:look]\n");
		return 1;
	}
	if(search(({"imprint","forget"}),parts[0])!=-1 && sizeof(parts)>=2){
		state = PETD->query_pet_state(me);
		write(render_pet_imprint(state,parts[1],me));
		return 1;
	}
	if(return_species!="")
		write("[继续培养当前宠物:pet detail "+return_species+"]|");
	write("[返回万灵谱:pet]|[返回游戏:look]\n");
	return 1;
}
