/** 根据账号真实万灵状态生成只读成长建议。 */

#ifndef XIAND_PET_GUIDANCE_PIKE
#define XIAND_PET_GUIDANCE_PIKE

private mapping(string:mixed) make_pet_guidance(string phase,
	string title,string detail,string action_label,string action_command,
	int current,int target)
{
	return ([
		"phase":phase,
		"title":title,
		"detail":detail,
		"action_label":action_label,
		"action_command":action_command,
		"current":current,
		"target":target,
	]);
}

private array(mapping(string:mixed)) append_pet_guidance(
	array(mapping(string:mixed)) suggestions,
	mapping(string:mixed) suggestion)
{
	if(sizeof(suggestions)<3)
		suggestions += ({suggestion});
	return suggestions;
}

/**
 * 最多返回三项按优先级排列的建议。只读取账号状态，不保存、不领取、
 * 不消耗材料，所有实际操作继续走原有命令和PETD事务校验。
 */
mapping(string:mixed) query_pet_growth_guidance(object player)
{
	mapping state;
	array(mapping(string:mixed)) suggestions = ({});
	mapping active_pet = ([]);
	string active_id;
	string character_id;
	int level;
	int hunt;
	int next_cost;
	int star_cost;
	int bond_cost;
	int team_count;
	int in_combat;
	if(!player)
		return (["ok":0,"message":"找不到当前人物。",
			"suggestions":suggestions]);
	state = query_pet_state(player);
	if(!state["ok"])
		return (["ok":0,"message":(string)state["message"],
			"suggestions":suggestions]);
	level = player->query_level();
	if(!(int)state["starter_claimed"]){
		if(level<PET_STARTER_LEVEL)
			suggestions = append_pet_guidance(suggestions,make_pet_guidance(
				"初契","先提升人物等级",
				"万灵初契在15级开放；智能挂机会寻找适合当前等级的怪物。",
				"打开智能挂机","autofight open",level,PET_STARTER_LEVEL));
		else
			suggestions = append_pet_guidance(suggestions,make_pet_guidance(
				"初契","领取第一位伙伴",
				"当康、鹿蜀、文鳐鱼强度路线不同，另外两只以后仍可稳定兑换。",
				"选择初契灵宠","pet starter",1,1));
		return (["ok":1,"message":"","suggestions":suggestions]);
	}
	if(!sizeof((array)state["pets"]))
		return (["ok":0,
			"message":"万灵谱显示已经初契却没有伙伴，已停止建议以保护账号数据。",
			"suggestions":suggestions]);
	character_id = player->query_name();
	active_id = (string)(state["active"][character_id] || "");
	foreach((array)state["pets"],mapping pet)
		if((string)pet["id"]==active_id){
			active_pet = pet;
			break;
		}
	if(!sizeof(active_pet) && sizeof((array)state["pets"])){
		foreach((array)state["pets"],mapping pet)
			if(!sizeof(active_pet) ||
			   (int)pet["power"]>(int)active_pet["power"])
				active_pet = pet;
		suggestions = append_pet_guidance(suggestions,make_pet_guidance(
			"出战","设置协战伙伴",
			"当前人物没有随行灵宠，助手已选出收藏中战力最高的一只。",
			"设为协战","pet active "+(string)active_pet["id"],0,1));
		return (["ok":1,"message":"","suggestions":suggestions]);
	}
	in_combat = player->query_in_combat && player->query_in_combat();
	if(in_combat){
		suggestions = append_pet_guidance(suggestions,make_pet_guidance(
			"协战","完成当前战斗",
			"交战中不建议换宠、培养、换装或消耗材料；当前伙伴仍会自动获得合适怪物的历练。",
			"查看当前战况","attack",
			(int)active_pet["xp"],(int)active_pet["xp_need"]));
		return (["ok":1,"message":"","suggestions":suggestions,
			"active_pet":copy_value(active_pet)]);
	}
	if(sizeof((mapping)state["pending_rift_rewards"]))
		suggestions = append_pet_guidance(suggestions,make_pet_guidance(
			"奖励","先领取限时裂隙奖励",
			"个人奖励资格保留7天，领取不会影响后续培养路线。",
			"立即领取","wanling_rift claim",0,1));
	hunt = (int)state["daily"]["hunt"];
	if(hunt<4){
		int hunt_progress = hunt>0 ? hunt-1 : 0;
		suggestions = append_pet_guidance(suggestions,make_pet_guidance(
			"日课",hunt>0 ? "继续今日万灵寻迹" : "开始今日万灵寻迹",
			"击败3只合适等级的不同真实怪物，可稳定获得灵印、灵露、残片和同心叶。",
			hunt>0 ? "继续寻迹" : "开始寻迹","pet_hunt",
			hunt_progress,3));
	}
	if(sizeof(active_pet) && (int)active_pet["level"]<PET_LEVEL_MAX){
		next_cost = 2+(int)active_pet["level"]/5;
		if((int)state["materials"]["spirit_dew"]>=next_cost)
			suggestions = append_pet_guidance(suggestions,make_pet_guidance(
				"成长","使用灵露加速一级",
				"材料足够，可立即培养；也可继续协战，让灵宠自动获得历练升级。",
				"灵露培养","pet level "+(string)active_pet["id"],
				(int)state["materials"]["spirit_dew"],next_cost));
		else
			suggestions = append_pet_guidance(suggestions,make_pet_guidance(
				"成长","随行战斗积累历练",
				"击败与人物等级接近的真实怪物会自动获得历练，副本和首领效率更高。",
				"打开智能挂机","autofight open",
				(int)active_pet["xp"],(int)active_pet["xp_need"]));
	}
	if(sizeof(active_pet) &&
	   sizeof((mapping)active_pet["equipment"])<3)
		suggestions = append_pet_guidance(suggestions,make_pet_guidance(
			"装备","补齐灵宠三件装备",
			"兽铠、灵饰、灵核分别强化生存、历练和攻击；初契装备可免费领取。",
			"整理灵宠装备","pet gear "+(string)active_pet["id"],
			sizeof((mapping)active_pet["equipment"]),3));
	if(sizeof(active_pet) && (int)active_pet["level"]>=20 &&
	   (string)(active_pet["equipment"]["spirit_core"] || "")!="" &&
	   !mappingp(active_pet["imprinted_skill"]))
		suggestions = append_pet_guidance(suggestions,make_pet_guidance(
			"技能","拓印一项主人技能",
			"20级且装备灵核后，可安全拓印主人真实掌握的主动攻击或治疗技能。",
			"选择拓印技能","pet skill "+(string)active_pet["id"],0,1));
	if(sizeof(active_pet)){
		star_cost = query_pet_star_cost((int)active_pet["star"]);
		if(star_cost>0 &&
		   (int)state["materials"]["egg_fragment"]>=star_cost)
			suggestions = append_pet_guidance(suggestions,make_pet_guidance(
				"进化","残片足够，可以升星",
				"3、6、9星会自动进化，十星达到真形圆满。",
				"立即升星","pet star "+(string)active_pet["id"],
				(int)state["materials"]["egg_fragment"],star_cost));
		bond_cost = (int)active_pet["bond"];
		if((int)active_pet["bond"]<PET_BOND_MAX && bond_cost>0 &&
		   (int)state["materials"]["bond_token"]>=bond_cost)
			suggestions = append_pet_guidance(suggestions,make_pet_guidance(
				"羁绊","深化伙伴羁绊",
				"羁绊会提高宠物成长并解锁新的山海小传。",
				"深化羁绊","pet bond "+(string)active_pet["id"],
				(int)state["materials"]["bond_token"],bond_cost));
	}
	if((int)state["weekly"]["rift_wins"]<3)
		suggestions = append_pet_guidance(suggestions,make_pet_guidance(
			"挑战","完成本周万灵裂隙",
			"三至五人组队挑战可获得完整灵卵保底、周目标与高效残片。",
			"查看万灵裂隙","wanling_rift",
			(int)state["weekly"]["rift_wins"],3));
	team_count = sizeof((array)(state["duel_teams"][character_id] || ({})));
	if(sizeof((array)state["pets"])>1 && team_count<3)
		suggestions = append_pet_guidance(suggestions,make_pet_guidance(
			"论道","配置三宠论道队伍",
			"不足三只会借用试炼灵宠；已有伙伴越多，越适合提前安排阵容。",
			"配置论道队伍","pet team",team_count,3));
	if((int)state["materials"]["spirit_mark"]>=PET_EXCHANGE_MARKS &&
	   (int)state["collection_count"]<(int)state["catalog_total"])
		suggestions = append_pet_guidance(suggestions,make_pet_guidance(
			"收藏","扩充山海万灵图鉴",
			"现有灵印已达到一次稳定兑换门槛，可按定位补充新的伙伴。",
			"查看可兑换灵宠","pet catalog",
			(int)state["materials"]["spirit_mark"],PET_EXCHANGE_MARKS));
	if(!sizeof(suggestions))
		suggestions = append_pet_guidance(suggestions,make_pet_guidance(
			"精研","尝试阴阳灵契合成",
			"基础成长目标已完成，可组合不同阴阳与种类，追求新契名、灵脉和属性结构。",
			"查看阴阳合成","pet fusion",1,1));
	return (["ok":1,"message":"","suggestions":suggestions,
		"active_pet":copy_value(active_pet)]);
}

#endif
