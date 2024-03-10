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
