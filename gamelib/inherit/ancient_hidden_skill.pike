/** 太古隐藏技能公共实现；具体技能仍以独立程序名注册和存档。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_SKILL;

int ancient_tier = 0;

protected void create()
{
	name = object_name(this_object());
	mapping config = ANCIENT_SKILLD->query_skill_config(name);
	if(!sizeof(config)){
		werror("[ANCIENT_SKILL] unknown skill id: %s\n",name);
		return;
	}
	ancient_tier = (int)config["tier"];
	name_cn = ANCIENT_SKILLD->query_colored_name(name);
	desc = "失落的"+(string)config["profession_cn"]+
		"太古传承，拾取后账号绑定且不可交易";
	s_type = "zhudong";
	s_skill_type = (string)config["type"];
	s_delayTime = 65+ancient_tier*5;
	s_lasttime = 12;
	s_curse_type = "hitte";
	skill_type += ({(string)config["profession"]});
	skill_rare = "ancient";
	if(s_skill_type=="buff" || s_skill_type=="team_guard")
		s_curse_type = "absorb";
	if(s_skill_type=="heal"){
		lingyi_heal_scope = 2;
		lingyi_think_scale = 5;
		lingyi_life_cap_percent = 25;
		if(ancient_tier>=4)
			lingyi_cleanse = 1;
	}
	for(int level=1;level<=5;level++){
		int cast = 300+(level-1)*75+ancient_tier*8;
		int base = 2300+(level-1)*(950+level*120)+ancient_tier*260;
		performs_cast[level] = cast;
		performs_level_limit[level] = 90+(level-1)*25;
		if(s_skill_type=="phy"){
			performs_attack[level] = base;
			performs_per[level] = 45+ancient_tier*5+level*8;
			performs_desc[level] = sprintf("增加%d%%武器伤害并附加%d点物理伤害，消耗法力%d点",
				performs_per[level],base,cast);
		}
		else if(s_skill_type=="dot"){
			performs_attack[level] = 260+level*130+ancient_tier*35;
			performs_desc[level] = sprintf("12秒持续造成每节拍%d点伤害，强持续伤害不会被弱效果覆盖，消耗法力%d点",
				performs_attack[level],cast);
		}
		else if(s_skill_type=="curse"){
			performs_attack[level] = 180+level*75+ancient_tier*25;
			performs_desc[level] = sprintf("12秒降低目标%d点命中，消耗法力%d点",
				performs_attack[level],cast);
		}
		else if(s_skill_type=="buff" || s_skill_type=="team_guard"){
			performs_attack[level] = 3200+level*1800+ancient_tier*420;
			performs_desc[level] = sprintf("12秒获得%d点基础护盾，消耗法力%d点",
				performs_attack[level],cast);
		}
		else if(s_skill_type=="taunt"){
			performs_attack[level] = 900+level*450+ancient_tier*120;
			performs_desc[level] = sprintf("强制锁定当前目标并增加%d点仇恨，消耗法力%d点",
				performs_attack[level],cast);
		}
		else if(s_skill_type=="heal"){
			performs_attack[level] = 1000+level*900+ancient_tier*180;
			performs_desc[level] = sprintf("同房队伍治疗%d+智力×5，单目标不超过25%%生命，消耗法力%d点",
				performs_attack[level],cast);
		}
		else{
			performs_mofa_attack[level] = ({base,base+900+ancient_tier*90});
			performs_desc[level] = sprintf("造成%d-%d点法术伤害，消耗法力%d点",
				performs_mofa_attack[level][0],
				performs_mofa_attack[level][1],cast);
		}
	}
}
