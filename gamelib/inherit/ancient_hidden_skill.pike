/** 太古隐藏技能公共实现；具体技能仍以独立程序名注册和存档。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_SKILL;

int ancient_tier = 0;

// 第八阶神太古血饮：按本段实际造成的伤害百分比回复自身生命。
// 战斗侧在 fight.pike 四个伤害落点统一结算，过量伤害不放大治疗。
int shen_taigu_lifesteal_percent = 0;

int query_shen_taigu_lifesteal_percent()
{
	return shen_taigu_lifesteal_percent;
}

protected void create()
{
	name = object_name(this_object());
	mapping config = ANCIENT_SKILLD->query_skill_config(name);
	if(!sizeof(config)){
		werror("[ANCIENT_SKILL] unknown skill id: %s\n",name);
		return;
	}
	ancient_tier = (int)config["tier"];
	rare_tier = ancient_tier;
	name_cn = ANCIENT_SKILLD->query_colored_name(name);
	desc = ancient_tier>=8 ?
		"失落的"+(string)config["profession_cn"]+
		"神太古血饮传承，高伤害并按实际伤害吸血回血；拾取后账号绑定且不可交易" :
		"失落的"+(string)config["profession_cn"]+
		"太古传承，拾取后账号绑定且不可交易";
	s_type = "zhudong";
	s_skill_type = (string)config["type"];
	s_delayTime = 65+ancient_tier*5;
	s_lasttime = 12;
	if(ancient_tier>=8)
		shen_taigu_lifesteal_percent = 50;
	// 太古诅咒默认使用封顶后的百分比命中压制。旧固定命中减值在
	// 高属性角色身上会先被巨量命中吞掉，再封顶为99，实际等于无效。
	s_curse_type = "hitte_percent";
	// 修罗千裂是狂妖第五档太古传承。后期命中会在99点封顶，继续
	// 降低固定命中值无法对高属性目标产生稳定收益；改为撕裂防御，
	// 由稀有控制快照按目标当前防御百分比成长。
	if(name=="shuraqianlie")
		s_curse_type = "defend";
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
		// 神太古血饮是超脱七阶曲线的终阶传承：伤害再上浮50%，
		// 配合太古系75秒的直伤冷却封顶形成"一击血饮"的定位。
		if(ancient_tier>=8)
			base = base*3/2;
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
			if(name=="shuraqianlie"){
				performs_attack[level] = 180+level*75+ancient_tier*25;
				performs_desc[level] = sprintf(
					"12秒撕裂目标防御，至少降低%d点防御，消耗法力%d点",
					performs_attack[level],cast);
			}
			else{
				performs_attack[level] = query_rare_control_percent(level);
				performs_desc[level] = sprintf(
					"12秒使目标最终命中率降低%d%%，消耗法力%d点",
					performs_attack[level],cast);
			}
		}
		else if(s_skill_type=="buff" || s_skill_type=="team_guard"){
			performs_attack[level] = 3200+level*1800+ancient_tier*420;
			performs_desc[level] = sprintf("12秒获得%d点基础护盾，消耗法力%d点",
				performs_attack[level],cast);
		}
		else if(s_skill_type=="taunt"){
			performs_attack[level] = 1050+level*525+ancient_tier*150;
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
	if(shen_taigu_lifesteal_percent>0)
		for(int level=1;level<=5;level++)
			if(sizeof(performs_desc[level]))
				performs_desc[level]+="；血饮：按实际伤害的"+
					(string)shen_taigu_lifesteal_percent+
					"%回复自身生命";
}
