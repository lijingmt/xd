#include <globals.h>
#include <mudlib/include/mudlib.h>
inherit LOW_BASE;
string s_type="zhudong";//技能类别：主动(zhudong),被动(beidong)
string s_skill_type = "";//技能类型 huo_mofa_attack,bing_mofa_attack,feng_mofa_attack,du_mofa_attack,dot,curse,phy,buff
int s_lasttime = 0;//技能持续伤害时间 包括诅咒和DOT

//boss技能系统，liaocheng于07/6/18添加                                                              
int boss_skill = 0;//是否为boss技能
int is_aoe = 0;//是否为群攻技能

string s_curse_type = "";//技能诅咒对方属性类型 str, dex, think, all,huoyan_defend,bingshuang_defend,fengren_defend,dusu_defend,all_mofa_defend,obsord,add_mama
int s_delayTime=0;//技能冷却时间
//技能升级熟练度要求
mapping(int:int) s_delayTime_add=([]);//技能的不同等级增加的冷却时间
mapping(int:int) s_lasttime_add=([]);//技能的不同等级增加的延续时间
mapping(int:int) performs_shuliandu=([
	1:2000,
	2:4000,
	3:8000,
	4:16000,
	5:32000,
	6:64000,
	7:128000,
	8:256000,
	9:512000,
	10:1024000	
]);
private string initer=(MUD_SKILLSD->add_skill(this_object()),""); 

int query_s_delayTime(int level){
	int d_time=s_delayTime;
	if(level&&level>=11){
		d_time += (int)s_delayTime_add[level];
	}
	return d_time;
}
int query_s_lasttime(int level){
	int l_time = s_lasttime;
	if(level&&level>=11){
		l_time += (int)s_lasttime_add[level];
	}
	return l_time;
}
