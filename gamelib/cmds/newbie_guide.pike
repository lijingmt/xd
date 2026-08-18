#include <command.h>
#include <gamelib/include/gamelib.h>

// 新手引导只分析真实人物状态，不靠点击按钮伪造完成进度。
int query_equipped_count(object player)
{
	mapping equipped;
	int count = 0;

	if(!player)
		return 0;
	equipped = player->query_equip();
	if(!equipped)
		return 0;
	foreach(values(equipped),object item){
		if(item)
			count++;
	}
	return count;
}

int query_learned_skill_count(object player)
{
	int count = 0;

	if(!player || !player->skills)
		return 0;
	foreach(values(player->skills),array skill_data){
		if(skill_data && sizeof(skill_data) && skill_data[0]>0)
			count++;
	}
	return count;
}

string query_fangshi_growth_guide(object player)
{
	string result = "";
	int level = player->query_level();

	result += "【方士修炼】\n";
	if(level<2)
		result += "○ 已有初始攻击技“灵弹术”；2级可继续学习“灵刃”。\n";
	else if(!player->skills["lingren"])
		result += "○ 你已达到2级，可以购买并学习攻击技“灵刃”。\n";
	else
		result += "√ 已有基础攻击技能“灵刃”。\n";

	if(level<8)
		result += "○ 8级可学习“灵治”，战斗中为自己恢复生命。\n";
	else if(!player->skills["lingzhi"] &&
		!player->skills["lingzhi_mystic"])
		result += "○ 你已达到8级，可以购买并学习“灵治”。\n";
	else
		result += "√ “灵治”治疗自己；进入战斗后从技能页施放。\n";

	if(level<24)
		result += "○ 24级解锁“灵莲铺”，可治疗自己和同房间队友。\n";
	else if(!player->skills["linglianpu"])
		result += "○ 你已达到24级，可以购买并学习“灵莲铺”。\n";
	else
		result += "√ “灵莲铺”始终治疗自己；有队伍时同时治疗同房间队友，没组队时只治疗自己。\n";

	result += "10级虎灵偏攻击，15级鹤灵持续治疗主人，20级龟灵偏防御。\n";
	result += "【方士中高阶路线】\n";
	if(level<30)
		result += "○ 30级召唤上限提升到2只。\n";
	else
		result += "√ 30级起可同时保留2只灵兽。\n";

	if(level<50)
		result += "○ 50级可学习“三灵合一”，发动三灵附体强化全属性。\n";
	else if(!player->skills["sanlingheyi"] &&
		!player->skills["sanlingheyi2"])
		result += "○ 已到50级，可购买并学习“三灵合一”。\n";
	else
		result += "√ 已掌握“三灵合一”，可施放三灵附体；60级开放三灵齐召。\n";

	if(level<60)
		result += "○ 60级召唤上限提升到3只，开放三灵齐召与本职业高级技能书轮换。\n";
	else{
		result += "√ 60级起可用“summon all”齐召三灵；高级书每天为每个职业独立轮换2种。\n";
		result += "[高级技能书:yushi_buy_hlbook_list]\n";
	}

	if(level<65)
		result += "○ 65级起可学习灵玄影、三灵合一和灵穿心的进阶替换技能。\n";
	else
		result += "√ 65级进阶书会替换旧技能，并保留原有召唤能力。\n";

	if(level<70)
		result += "○ 70级可学习“灵裂兽”；实际等级70以上的怪物才有极低概率掉落隐藏大神技能书。\n";
	else
		result += "√ 隐藏大神技能书只由实际等级70以上怪物极低概率掉落，不会出现在任何商店。\n";

	if(level<75)
		result += "○ 75级开放灵玄、灵火烧、灵治、灵盾与虎灵的秘传替换书。\n";
	else
		result += "√ 75级秘传可强化控制、伤害、治疗、防护与虎灵召唤，替换后原功能不会丢失。\n";

	if(level<20)
		result += "○ 20级可向两边主城广场的方士传人领取专属挂件任务。\n";
	else if(level<53)
		result += "√ 已可领取20级方士专属挂件任务；53级还有四段职业传承任务。\n";
	else
		result += "√ 可向方士传人完成53级四段职业传承，最终获得“三灵合一”技能书。\n";
	result += "[购买方士技能书:buy_items book fangshi]|[查看技能:myskills]|[召唤灵兽:summon]\n";
	return result;
}

string query_zhenyue_growth_guide(object player)
{
	string result = "";
	int level = player->query_level();

	result += "【镇越守御】\n";
	result += "岳击是初始高仇恨攻击；2级山印永久加防，5级镇岩诀建立个人守势。\n";
	if(level<15)
		result += "○ 15级学习地震吼，可靠把当前敌人的最高仇恨转向自己。\n";
	else if(!player->skills["dizhenhou"])
		result += "○ 已到15级，可购买地震吼；组队时先吼再稳定攻击。\n";
	else
		result += "√ 地震吼会在当前最高仇恨上追加余量，但有18秒冷却。\n";
	if(level<20)
		result += "○ 20级解锁山河壁：未组队只护自己，组队只护同房间存活队友。\n";
	else if(!player->skills["shanhebi"])
		result += "○ 已到20级，可购买镇越的核心队伍技能山河壁。\n";
	else
		result += "√ 山河壁使用独立护盾，不覆盖队友原有增益，护盾耗尽或到时消失。\n";
	result += "30级玄铁盾可与山河壁共存；40级岳反震兼顾输出和仇恨；50级镇越真身扩展生命上限。\n";
	result += "60级万山不孤强化队伍护盾；70级镇魂吼提供更高仇恨余量。\n";
	result += "实际等级70以上怪物才可能掉落万山朝拱、不周震击、天地成壁三本大神传承。\n";
	result += "[购买镇越技能书:buy_items book zhenyue]|[查看技能:myskills]|[队伍:my_term]\n";
	return result;
}

string query_tianxiang_growth_guide(object player)
{
	string result = "";
	int level = player->query_level();

	result += "【天象观星】\n";
	result += "星芒是初始火系法术；不同星术命中会凝聚星痕，最多三层，十五秒内有效。\n";
	if(level<5)
		result += "○ 5级学习寒辰，用不同元素交替积蓄星痕。\n";
	else if(!player->skills["hanchen"])
		result += "○ 已到5级，可购买寒辰并练习第二种星痕生成法术。\n";
	else
		result += "√ 已掌握寒辰；星芒、寒辰交替命中会刷新星痕时限。\n";
	if(level<15)
		result += "○ 15级学习星壁，获得可耗尽的个人法术护盾。\n";
	else if(!player->skills["xingbi"])
		result += "○ 已到15级，可购买星壁提高独行容错。\n";
	else
		result += "√ 星壁不生成或消耗星痕，可在积蓄前先建立防护。\n";
	if(level<20)
		result += "○ 20级学习星锁，短时削弱目标法术抗性。\n";
	else
		result += "√ 星锁有命中、持续与冷却限制，不提供永久减抗。\n";
	if(level<60)
		result += "○ 60级学习星落，消耗现有星痕形成核心爆发。\n";
	else if(!player->skills["xingluo"])
		result += "○ 已到60级，可在高级技能书轮换中取得星落。\n";
	else
		result += "√ 星落在普通PVE每层提高10%，面对玩家或Boss每层提高8%，最多三层。\n";
	result += "换房、脱战、死亡、掉线或星痕超时都会清空层数，不能预存到下一场战斗。\n";
	result += "实际等级70以上怪物才可能掉落星河坠落、周天静止、万象星壁三本大神传承。\n";
	result += "[购买天象技能书:buy_items book tianxiang]|[查看技能:myskills]|[每级历练:growth_task]\n";
	return result;
}

string query_lingyi_growth_guide(object player)
{
	string result = "";
	int level = player->query_level();
	result += "【灵医济世】\n";
	result += "灵针是初始自卫法术；5级回春会救治自己或同房间同队中生命比例最低者。\n";
	if(level<5)
		result += "○ 5级学习回春，先受伤再施放，观察第一层药契。\n";
	else if(!player->skills["huichun"])
		result += "○ 已到5级，可购买回春；未组队时它会稳定治疗自己。\n";
	else
		result += "√ 回春只选择存活、同房、同区的队友；有效治疗凝成药契，最多三层。\n";
	if(level<20)
		result += "○ 20级学习清心，治疗后按持续伤害、诅咒、控制顺序净化一项负面状态。\n";
	else
		result += "√ 清心不会复活死者，也不会治疗队外、跨房或跨逻辑区玩家。\n";
	if(level<50)
		result += "○ 50级学习玉露，开始承担同房队伍群体治疗。\n";
	else
		result += "√ 玉露与60级甘霖会治疗同房存活队友；未组队时仍只治疗自己。\n";
	result += "70级续命会消耗全部药契，每层提高15%治疗；没有药契也可正常急救。\n";
	result += "换房、脱战、死亡、掉线或药契超时都会清空层数；普通单体/群体治疗分别受35%/20%生命上限保护。\n";
	result += "46级药雾天罗会群攻同房合法敌人；百草助手可分别设置是否攻击仙、妖、中立玩家。\n";
	result += "任意五门灵医技能满段（100%掌握）后解锁每日一次百炼复苏，八门/十二门提高到两次/三次。\n";
	result += "实际等级70以上怪物才可能掉落慈心普渡、回命天露、万木新春、六合回春四本大神传承。\n";
	result += "[购买灵医技能书:buy_items book lingyi]|[查看技能:myskills]|[队伍:my_term]|[每级历练:growth_task]\n";
	return result;
}

string query_wuxiang_growth_guide(object player)
{
	string result = "";
	int level = player->query_level();
	result += "【无相补位】\n";
	result += "无相拳是入门近战；5级无相诀补法术输出；10级无相医让自己能扛线。\n";
	if(level<15)
		result += "○ 15级无相盾、20级无相吼提供短时减伤与全属性爆发。\n";
	else
		result += "√ 无相盾约为护盾专精五成半；无相吼持续30秒、冷却60秒，不能常驻。\n";
	if(level<35)
		result += "○ 30/35级解锁无相剑/无相焰，进入双系轮转。\n";
	else
		result += "√ 物理与法术双修；无相焰每3秒轮转，发挥法术专精60%威力，随可用阶段覆盖2至10个目标。\n";
	result += "无相心法：力量/敏捷/智力的最高项会按 50% 加成另外两系，单次结算生效，不写入存档。\n";
	result += "120级解锁无相化身：每天一次免疫致命伤，恢复25%生命；自杀、切磋、城战不触发。\n";
	result += "实际等级70以上怪物才可能掉落无相·归墟/混元/无极三本大神传承。\n";
	result += "[购买无相技能书:buy_items book wuxiang]|[查看技能:myskills]|[队伍:my_term]|[每级历练:growth_task]\n";
	return result;
}

string query_taiji_growth_guide(object player)
{
	string result = "";
	int level = player->query_level();
	result += "【太极·生死轮转】\n";
	result += "太极拳是入门近战；5级太极诀补法术输出；10级太极医让自己能扛线。\n";
	if(level<15)
		result += "○ 15级太极盾、20级太极吼提供短时减伤与全属性爆发。\n";
	else
		result += "√ 太极盾吸收一次伤害；太极吼使全属性短时上升，配合心法爆发。\n";
	if(level<35)
		result += "○ 30/35级解锁太极剑/焰，进入双系轮转。\n";
	else
		result += "√ 物理与法术双修；同房群攻用太极焰覆盖敌对目标。\n";
	result += "太极心法：力量/敏捷/智力的最高项会按 65% 加成另外两系（vs 无相 50%），即时结算。\n";
	result += "太极·生生不息：致命伤自动复活，恢复 30% 生命，5 分钟冷却（PVP 也可触发）。\n";
	result += "太极·复阴：通过命令 taiji_fuyin <队友名> 主动复活同房同队的鬼魂队友，独立 5 分钟冷却。\n";
	result += "实际等级70以上怪物才可能掉落太极·归墟/混元/无极三本大神传承。\n";
	result += "[购买太极技能书:buy_items book taiji]|[查看技能:myskills]|[队伍:my_term]|[复活队友:taiji_fuyin]|[每级历练:growth_task]\n";
	return result;
}

string render_guide(object player)
{
	string result = "";
	int equipped_count;
	int learned_count;

	if(!player)
		return "无法读取人物状态。\n";

	equipped_count = query_equipped_count(player);
	learned_count = query_learned_skill_count(player);
	result += "【新手引导】当前人物检查\n";
	result += player->query_race_cn(player->query_raceId())+"·"+
		player->query_profe_cn(player->query_profeId())+" | "+
		player->query_level()+"级\n";
	result += "--------\n";

	result += "【1. 装备】已穿 "+equipped_count+" 件\n";
	if(equipped_count<4)
		result += "○ 还有基础空位，先让助手补穿背包里符合条件的最好装备。\n";
	else
		result += "√ 基础武器和防具已经穿好；助手只补空位，不替换现有装备。\n";
	result += "[一键穿装:auto_equip]|[查看物品:inventory]\n";

	result += "【2. 技能】已学 "+learned_count+" 项\n";
	if(player->query_profeId()=="fangshi")
		result += query_fangshi_growth_guide(player);
	else if(player->query_profeId()=="zhenyue")
		result += query_zhenyue_growth_guide(player);
	else if(player->query_profeId()=="tianxiang")
		result += query_tianxiang_growth_guide(player);
	else if(player->query_profeId()=="lingyi")
		result += query_lingyi_growth_guide(player);
	else if(player->query_profeId()=="wuxiang")
		result += query_wuxiang_growth_guide(player);
	else if(player->query_profeId()=="taiji")
		result += query_taiji_growth_guide(player);
	else if(player->query_profeId()=="zhaoming")
		result += "照命传承不进入技能书商店；完成本人S1八十一章并达到120级后，按顺序完成七卷四十九难逐卷领悟。\n"+
			"[查看幻境主线:illusion_realm]|[查看四十九难:illusion_hidden]|[查看技能:myskills]\n";
	else
		result += "[购买本职业技能书:buy_items book "+
			player->query_profeId()+"]|[查看技能:myskills]\n";

	result += "【3. 打怪与成长】\n";
	result += "从地图选择适合等级的区域，点击怪物后开始战斗；怪物会提供经验、金钱和随机装备。\n";
	result += "新装备先放入背包，再用一键穿装补空位；已有装备不会被自动顶掉。\n";
	if(player->query_level()<=NEWBIED->query_newbie_supply_max_level())
		result += "30级前可免费领取新手红蓝药；挂机缺药时会自动尝试领取本小时剩余额度。1～19级还可手动免费领取一次二倍追光露。\n"+
			"[新手补给商店:newbie_shop]|[挂机设置:autofight open]\n";
	result += "挂机助手会按真实怪物等级自动选择练级区、逐图找怪；战斗中会吃药，缺药则前往安全地点休息后继续。\n";
	result += "[查看地图:map_display]|[查看任务:mytasks]|[每级职业历练:growth_task]|[查看排行榜:look_top]\n";
	if(player->query_level()<15)
		result += "○ 15级开放全职业通用的山海万灵初契；灵宠可升级、升星、进化，并有限参与PVE和人物PVP。\n";
	else
		result += "√ 已可从当康、鹿蜀、文鳐鱼中选择第一位伙伴，另外两位以后可稳定兑换。\n[山海万灵谱:pet]|[今日修行:daily_cultivation]\n";

	result += "【4. 队伍、聊天与家园】\n";
	result += "[队伍:my_term]|[聊天:chatroom_list]";
	if(player->query_home_path() && player->query_home_path()!="")
		result += "|[返回家园:home_return "+player->query_home_path()+"]\n";
	else
		result += "|家园系统不限制职业，可在家园区域购置后使用种养、功能房和店铺。\n";

	if(player->query_raceId()=="third")
		result += "中立职业可使用仙妖两边的驿站、休息点、仓库、聊天和荣誉商店，也可加入两边帮派；建帮归属由当时所在仙城或妖城决定，但不能转换阵营。\n";

	result += "--------\n";
	result += "[返回游戏:look]\n";
	return result;
}

string render_tutorial(object player)
{
	mapping state;
	string result = "";

	if(!player)
		return "无法读取人物状态。\n";
	if(player->query_profeId()=="zhaoming")
		return "【照命·归来者指引】\n"+
			"你已用五个不同S1职业完成八十一章并达到120级，无需重复普通新手课程。\n"+
			"照命本人仍须完成S1九卷八十一章；达到120级后，七卷四十九难才会开启。\n"+
			"四十九难的狩猎、探索与首领都按真实行动记账，不能点击跳过。\n"+
			"[查看幻境主线:illusion_realm]|[查看四十九难:illusion_hidden]\n"+
			"[照命成长路线:newbie_guide roadmap]|[返回游戏:look]\n";
	state = NEWBIED->query_step_state(player);
	if(state["complete"]){
		result += "【新手引导·已毕业】\n";
		result += "你已经完成"+state["total"]+"步真实操作课程，"+
			state["title"]+"。\n";
		result += "接下来按职业成长路线继续学习中高阶技能、装备、副业、家园、帮派和副本。\n";
		result += "[查看职业成长路线:newbie_guide roadmap]\n";
		result += "[查看完整系统说明:newbie_guide overview]\n";
		result += "[每级职业历练:growth_task]|[查看任务:mytasks]\n";
		result += "[返回游戏:look]\n";
		return result;
	}

	result += "【新手引导 "+state["step"]+"/"+state["total"]+"】\n";
	result += player->query_race_cn(player->query_raceId())+"·"+
		player->query_profe_cn(player->query_profeId())+" | "+
		player->query_level()+"级\n";
	result += "当前课程："+state["title"]+"\n";
	result += state["desc"]+"\n";
	if(state["progress"] && state["progress"]!="")
		result += state["progress"]+"\n";
	result += "--------\n";
	if(state["ready"]){
		result += "√ 已通过服务器真实状态验证；正常操作时会立即自动结算并弹出完成提示。\n";
		result += "[补领本步奖励:newbie_guide check]\n";
	}
	else{
		result += "○ 本步尚未完成。完成指定操作后会立即自动结算，无需返回本页检查。\n";
		if(state["action_command"] && state["action_command"]!="")
			result += "["+state["action_label"]+":"+
				state["action_command"]+"]\n";
		result += "[手动检查历史进度:newbie_guide check]\n";
	}
	if(state["step"]==9)
		result += "提示：先点击当前场景中的怪物，进入战斗后再从技能页施放"+
			NEWBIED->query_profession_config(player)["starter_cn"]+"。\n";
	if(state["step"]==20 && player->query_profeId()=="fangshi")
		result += "[阅读虎灵技能书:inventory]|[召唤虎灵:summon huling]\n";
	result += "--------\n";
	result += "[职业成长路线:newbie_guide roadmap]|"+
		"[完整系统说明:newbie_guide overview]\n";
	result += "[返回游戏:look]\n";
	return result;
}

string query_profession_roadmap(string profession)
{
	string result = "";

	switch(profession){
		case "jianxian":
			result += "剑仙：1级切云斩入门；9级裂甲剑风破防；14级御风剑气；"+
				"19级起凝气成盾；24级分水斩。中高阶强化坦度、仇恨与剑气爆发。\n";
			break;
		case "yushi":
			result += "羽士：1级萤火咒入门；9级凝心决护盾；14级寒冰咒；"+
				"19级静心决；24级炎爆咒；29级封天冻地。中高阶兼顾法伤、护盾与控制。\n";
			break;
		case "zhuxian":
			result += "诛仙：1级随心诀入门；9级飘忽不定；14级斩妖诀；"+
				"19级破魔心法；24级玄天剑阵；29级撕魂裂魄。中高阶强调机动、剑阵与爆发。\n";
			break;
		case "kuangyao":
			result += "狂妖：1级撕裂入门；9至21级分段提升嗜血狂暴；"+
				"14级碎骨重击；19级崩裂冲撞；24级放血；29级狂化。中高阶以近战爆发和暴击成长为核心。\n";
			break;
		case "wuyao":
			result += "巫妖：1级巫毒术入门；9级妖术结界；14级打风刃；"+
				"19级泥沼术；24级腐蚀术；29级摄魂术。中高阶擅长护盾、持续伤害和限制敌人。\n";
			break;
		case "yinggui":
			result += "影鬼：1级伏击入门；9至21级分段提升鬼踪；"+
				"14级杀戮；24级剖心剔骨；29级幻影残像。中高阶围绕闪避、潜行和刺杀爆发成长。\n";
			break;
		case "fangshi":
			result += "方士：1级灵弹术，2级灵刃，8级灵治自疗；"+
				"10级虎灵攻击、15级鹤灵治疗、20级龟灵防护；24级灵莲铺治疗自己和同房间队友。\n";
			result += "30级召唤上限2只；50级三灵合一；60级上限3只并可齐召三灵；"+
				"65级进阶替换书；70级隐藏大神书；75级秘传替换书。\n";
			result += "[查看召唤与灵契:summon]|[方士技能书:buy_items book fangshi]\n";
			break;
		case "zhenyue":
			result += "镇越：1级岳击建立仇恨；2级山印永久加防；5级镇岩诀；"+
				"10级横山击；15级地震吼可靠夺取当前目标；20级山河壁保护同房间队伍。\n";
			result += "30级玄铁盾与山河壁双层承压；40级岳反震；50级镇越真身；"+
				"60级万山不孤；70级镇魂吼，并开始挑战70级隐藏大神书掉落资格怪；"+
				"80级起可学习三本掉落限定大神传承。\n";
			result += "[镇越技能书:buy_items book zhenyue]|[队伍:my_term]\n";
			break;
		case "tianxiang":
			result += "天象：1级星芒、5级寒辰、10级流星交替积蓄星痕；星痕最多三层、15秒未刷新会消散；15级星壁提高容错；"+
				"20级星锁削弱法抗；25级曜光、30级天旋、40级星雨扩展元素循环。\n";
			result += "50级月引；60级星落消耗至多三层星痕形成受控爆发；70级九星连珠，"+
				"并开始挑战70级隐藏大神书掉落资格怪；80级起可学习三本极低概率掉落的大神传承。\n";
			result += "[天象技能书:buy_items book tianxiang]|[查看技能:myskills]\n";
			break;
		case "lingyi":
			result += "灵医：1级灵针自卫；5级回春智能救急；20级清心兼顾单体净化；28级护心提高自身容错；35级灵愈强化急救。\n";
			result += "46级药雾天罗群攻敌对目标，并可定制攻击仙、妖、中立玩家；50级玉露治疗同房队伍；53级完成四段职业任务获得百草诀；60级甘霖群疗并净化；70级续命消耗药契强化急救；80级起可学习四本掉落限定大神传承。\n";
			result += "任意五门技能满段解锁百炼复苏，八门/十二门时每日次数提升到2/3次。\n";
			result += "[灵医技能书:buy_items book lingyi]|[查看技能:myskills]|[队伍:my_term]\n";
			break;
		case "wuxiang":
			result += "无相：1级无相拳、5级无相诀、10级无相医兼顾近战法术治疗三系；15级无相盾、20级无相吼提供短时容错与爆发。\n";
			result += "30/35级无相剑/焰形成物法双修；无相焰每3秒轮转、仅有专精60%威力并随阶段覆盖2至10个目标；净化、盾、召唤和群疗均采用专精级冷却。\n";
			result += "无相原则是广而不精：护盾与治疗约为对应专精的五成至六成，不会替代镇越、灵医等旧职业。\n";
			result += "70/85级无相击/灭是高阶物法输出；100级万象归一短时爆发；120级无相化身每日免疫一次致命伤。\n";
			result += "无相心法让最高属性的一半加成另外两系；实际等级70以上怪物才可能掉落归墟/混元/无极三本大神传承。\n";
			result += "[无相技能书:buy_items book wuxiang]|[查看技能:myskills]|[队伍:my_term]\n";
			break;
	

		case "taiji":
			result += "太极：1级太极拳、5级太极诀、10级太极医兼顾近战法术治疗三系；比无相综合实力强 30%。\n";
			result += "15级太极盾、20级太极吼、30/35级太极剑/焰、40级太极净、50级太极壁、55级太极唤、60级太极雨、70/85级太极击/灭。\n";
			result += "100级太极归真短时爆发；太极心法让最高属性的 65% 加成另外两系。\n";
			result += "太极·生生不息：致命伤自动复活，恢复 30% 生命，5 分钟冷却（PVP 可触发）。\n";
			result += "太极·复阴：主动复活同房同队鬼魂队友，独立 5 分钟冷却。\n";
			result += "[太极技能书:buy_items book taiji]|[查看技能:myskills]|[队伍:my_term]|[复活队友:taiji_fuyin]\n";
			break;
		case "zhaoming":
			result += "照命：S1限定隐藏职业，以五个不同职业完整通关且达到120级的账号历程解锁。\n";
			result += "照命诀为入门心法；照命本人完成八十一章并达到120级后，依次通过七卷四十九难。\n";
			result += "每卷七难都要求真实狩猎、探索与首领战；卷末领悟专属传承，十个里程碑取得账号绑定寰极十件套。\n";
			result += "[S1幻境主线:illusion_realm]|[七卷四十九难:illusion_hidden]|[查看技能:myskills]\n";
			break;
	}
	return result;
}

string render_roadmap(object player)
{
	string result = "";
	string profession;

	if(!player)
		return "无法读取人物状态。\n";
	profession = player->query_profeId();
	result += "【"+player->query_profe_cn(profession)+"·从入门到高阶】\n";
	result += query_profession_roadmap(profession);
	if(profession=="zhaoming")
		result += "[七卷四十九难:illusion_hidden]|[查看技能:myskills]\n\n";
	else
		result += "[本职业技能书:buy_items book "+profession+
			"]|[查看技能:myskills]\n\n";

	result += "【任务成长】\n";
	result += "每一级领取职业历练；20级起留意职业挂件任务，53级完成本职业多段传承。"+
		"任务列表会显示可接、进行中和提交目标，任务引导只前往服务器核验过的安全地图。\n";
	result += "[每级职业历练:growth_task]|[任务列表:mytasks]\n\n";

	result += "【装备与副业】\n";
	result += "怪物会掉落适合等级的随机装备；先检查职业、等级和属性限制，再穿戴。"+
		"一键穿装只补空位，想换更好的装备要先手动脱下旧装备。"+
		"采矿、锻造、熔炼、裁缝、制甲、采药与炼丹构成长期装备成长。\n";
	result += "[查看物品:inventory]|[一键穿装:auto_equip]|[查看副业:myskills]\n\n";

	result += "【队伍与副本】\n";
	result += "先建立或加入七星阵队伍，再从副本入口进入；副本战利品进入队伍仓库，由队长及时分配。"+
		"方士组队治疗只影响同房间队友；镇越山河壁也只保护同房间存活队友，没组队时两者都保留自用效果。\n";
	result += "[队伍:my_term]|[查看地图:map_display]\n\n";
	result += "【山海万灵】\n";
	result += "15级起所有职业都可缔结灵宠。万灵裂隙需要3—5人，但破阵、守御、疗愈、封印均可由任何职业选择；灵宠论道采用三宠标准属性。\n";
	result += "[万灵谱:pet]|[今日修行:daily_cultivation]|[万灵裂隙:wanling_rift]\n\n";

	result += "【帮派、家园与交易】\n";
	result += "10级后可了解帮派申请与建帮；家园可发展功能房、种养、狗狗和私家小店。"+
		"仓库、邮件、聊天、排行和玉石兑换均不限制职业；购买时玉石会自动拆分并找零。\n";
	result += "[帮派手册:bang_readme]|[我的家园:home_myzone]|"+
		"[收件箱:mailbox]|[玉石:yushi_change]\n\n";

	result += "【60级以后】\n";
	result += "各职业每天独立轮换高级技能书；实际等级70以上怪物才有极低概率掉落本职业隐藏大神技能书，隐藏书不会进商店。\n";
	result += "[高级技能书:yushi_buy_hlbook_list]|[排行榜:look_top]\n";
	result += "--------\n";
	result += "[继续分步引导:newbie_guide]|[完整系统说明:newbie_guide overview]\n";
	result += "[返回游戏:look]\n";
	return result;
}

int main(string|zero arg)
{
	object me = this_player();
	string result = "";

	if(arg=="overview")
		result = render_guide(me);
	else if(arg=="roadmap")
		result = render_roadmap(me);
	else if(arg=="check"){
		mapping claim = NEWBIED->claim_with_notice(me);
		if(claim["code"]==1)
			result += "本步还没有通过真实操作验证，重复点击检查不会跳过课程。\n\n";
		else if(claim["code"]==2){
			result += "【第"+claim["step"]+"步完成】"+
				claim["title"]+"\n";
			if(claim["reward"] && claim["reward"]!="")
				result += claim["reward"]+"\n";
			if(claim["next_step"]>NEWBIED->query_total_steps())
				result += "恭喜，你已经完成全部新手课程！\n\n";
			else
				result += "下一步已经解锁。\n\n";
		}
		else if(claim["code"]==3)
			result += "你已经完成全部新手课程。\n\n";
		else if(claim["code"]==4)
			result += claim["reward"]+"\n\n";
		result += render_tutorial(me);
	}
	else
		result = render_tutorial(me);
	write(result);
	return 1;
}
