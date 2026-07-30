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
	else
		result += "[购买本职业技能书:buy_items book "+
			player->query_profeId()+"]|[查看技能:myskills]\n";

	result += "【3. 打怪与成长】\n";
	result += "从地图选择适合等级的区域，点击怪物后开始战斗；怪物会提供经验、金钱和随机装备。\n";
	result += "新装备先放入背包，再用一键穿装补空位；已有装备不会被自动顶掉。\n";
	result += "[查看地图:map_display]|[查看任务:mytasks]|[每级职业历练:growth_task]|[查看排行榜:look_top]\n";

	result += "【4. 队伍、聊天与家园】\n";
	result += "[队伍:my_term]|[聊天:chatroom_list]";
	if(player->query_home_path() && player->query_home_path()!="")
		result += "|[返回家园:home_return "+player->query_home_path()+"]\n";
	else
		result += "|家园系统不限制职业，可在家园区域购置后使用种养、功能房和店铺。\n";

	if(player->query_raceId()=="third")
		result += "方士为中立职业，可使用仙妖两边的驿站、休息点、仓库、聊天和荣誉商店，也可加入两边帮派；建帮归属由当时所在仙城或妖城决定，但不能转换阵营。\n";

	result += "--------\n";
	result += "[返回游戏:look]\n";
	return result;
}

int main(string|zero arg)
{
	object me = this_player();
	write(render_guide(me));
	return 1;
}
