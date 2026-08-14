#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit WAP_SKILL;

// 套装技能的阶级由当前十件套决定，不通过熟练度成长。
int query_skill_level_max(){ return 6; }
int query_newmoon_set_skill(){ return 1; }

// 新月至寰极依次缩短冷却：120/114/108/102/96/90秒。
int query_s_delayTime(int level)
{
	if(level<1)
		level=1;
	if(level>6)
		level=6;
	return 126-level*6;
}

// 套装技能沿用统一伤害公式，仅为一次爆发增加玩家与首领封顶。
int query_rare_direct_pvp_cap_percent(){ return 12; }
int query_rare_direct_boss_cap_percent(){ return 2; }

string query_performs_desc(int level)
{
	string result=::query_performs_desc(level);
	if(result=="")
		return result;
	return result+"；完整十件套生效，脱下或损坏任一件即停用；实战冷却"+
		(string)query_s_delayTime(level)+"秒";
}
