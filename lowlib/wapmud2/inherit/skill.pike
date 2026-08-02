#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_SKILL;
inherit WAP_F_VIEW_PICTURE;
mapping(int:int) performs_attack=([]);//物理技能伤害
mapping(int:int) performs_per=([]);//物理技能伤害增加百分比
mapping(int:int) performs_cast=([]);//技能耗费法力
array(string) skill_type=({});
mapping(int:array(int)) performs_mofa_attack=([]);
mapping(int:string) performs_desc=([]);//技能等级描述
mapping(int:int) performs_level_limit=([]);//技能等级限制
int effect_value;//70技能特有的字段，用于记录一些效果值
string skill_rare="";//技能稀有度标记，普通技能为空
int hate_multiplier=100;//物理技能仇恨倍率，100为普通技能
int star_mark_gain=0;//天象法术命中后获得的星痕数
int star_mark_consume=0;//天象法术命中后是否消耗现有星痕
int lingyi_heal_scope=0;//灵医治疗范围：0兼容旧治疗，1智能单体，2同房队伍
int lingyi_think_scale=0;//灵医治疗受智力加成的倍率
int lingyi_cleanse=0;//是否在治疗后净化一个负面状态
int lingyi_life_cap_percent=0;//单次对每个目标最多恢复其生命上限百分比
int lingyi_pact_gain=0;//有效治疗后获得的药契层数
int lingyi_pact_consume=0;//有效治疗时是否消耗全部药契
int lingyi_room_aoe=0;//灵医房间群攻：只由服务端筛选合法非队友目标
int lingyi_aoe_power_percent=0;//房间群攻相对普通法术的伤害倍率

int query_hate_multiplier(){
	if(hate_multiplier<1)
		return 100;
	return hate_multiplier;
}

int query_star_mark_gain(){
	return star_mark_gain>0 ? star_mark_gain : 0;
}

int query_star_mark_consume(){
	return star_mark_consume ? 1 : 0;
}

int query_lingyi_heal_scope(){
	return lingyi_heal_scope;
}

int query_lingyi_think_scale(){
	return lingyi_think_scale>0 ? lingyi_think_scale : 0;
}

int query_lingyi_cleanse(){
	return lingyi_cleanse ? 1 : 0;
}

int query_lingyi_life_cap_percent(){
	return lingyi_life_cap_percent>0 ? lingyi_life_cap_percent : 0;
}

int query_lingyi_pact_gain(){
	return lingyi_pact_gain>0 ? lingyi_pact_gain : 0;
}

int query_lingyi_pact_consume(){
	return lingyi_pact_consume ? 1 : 0;
}

int query_lingyi_room_aoe(){
	return lingyi_room_aoe ? 1 : 0;
}

int query_lingyi_aoe_power_percent(){
	if(lingyi_aoe_power_percent<1)
		return 100;
	if(lingyi_aoe_power_percent>100)
		return 100;
	return lingyi_aoe_power_percent;
}

int query_performs_attack(int level){
	if(!level)
		return 0;
	if(performs_attack&&sizeof(performs_attack))
		return (int)performs_attack[level];
	else
		return 0;
}
int query_performs_per(int level){
	if(!level)
		return 0;
	if(performs_per&&sizeof(performs_per))
		return (int)performs_per[level];
	else
		return 0;
}
int query_performs_cast(int level){
		if(!level)
		return 0;
	if(performs_cast&&sizeof(performs_cast))
		return (int)performs_cast[level];
	else
		return 0;
}
int query_performs_mofa_attack_high(int level){
	if(!level)
		return 0;
	if(performs_mofa_attack&&sizeof(performs_mofa_attack))
		return (int)performs_mofa_attack[level][1];
	else
		return 0;
}
int query_performs_mofa_attack_low(int level){
	if(!level)
		return 0;
	if(performs_mofa_attack&&sizeof(performs_mofa_attack))
		return (int)performs_mofa_attack[level][0];
	else
		return 0;
}
string query_performs_desc(int level){
	if(!level)
		return "";
	if(performs_desc&&sizeof(performs_desc))
		return (string)performs_desc[level];
	else
		return "";
}
int query_performs_level_limit(int level){
	if(!level)
		return 0;
	if(performs_level_limit&&sizeof(performs_level_limit))
		return performs_level_limit[level];
	else
		return 0;
}
mapping query_performs_level_limit_all(){
	if(performs_level_limit&&sizeof(performs_level_limit))
		return performs_level_limit;
	else
		return ([]);
}

// 主动技能的熟练度上限。
// 老职业多数为10级；明确配置了多段等级门槛的技能以实际段数为准，
// 避免练到不存在的等级后说明和成长断档。
int query_skill_level_max(){
	int skill_level_max = 10;
	if(performs_level_limit && sizeof(performs_level_limit) > 1 &&
	   sizeof(performs_level_limit) < skill_level_max)
		skill_level_max = sizeof(performs_level_limit);
	return skill_level_max;
}
