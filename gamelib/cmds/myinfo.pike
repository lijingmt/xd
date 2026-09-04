#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	s += "［人物属性］\n";
	s += "[［人物状态］:myhp]\n";
	s += "[［武器装备］:mytools]\n";
	
	s += "攻击强度："+format_game_number(me->query_low_attack_desc())+
		"-"+format_game_number(me->query_high_attack_desc())+"\n";
	s += "防御强度："+format_game_number(me->query_defend_power())+"\n";
	
	s += "生命力："+format_game_number(me->get_cur_life())+"/"+
		format_game_number(me->query_life_max())+"\n";
	s += "法力值："+format_game_number(me->get_cur_mofa())+"/"+
		format_game_number(me->query_mofa_max())+"\n";
	////////////////////////////////////////////////////////////////////////////////
	/* 三系属性直接显示战斗实际值（含心法），括号标注心法部分。 */
	{
		int heart_str = (int)me->query_taiji_heart_bonus("str")+
			(int)me->query_wuxiang_heart_bonus("str");
		int heart_dex = (int)me->query_taiji_heart_bonus("dex")+
			(int)me->query_wuxiang_heart_bonus("dex");
		int heart_think = (int)me->query_taiji_heart_bonus("think")+
			(int)me->query_wuxiang_heart_bonus("think");
		int base_str = (int)me->get_cur_str();
		int base_dex = (int)me->get_cur_dex();
		int base_think = (int)me->get_cur_think();
		int total_str = (int)me->query_str();
		int total_dex = (int)me->query_dex();
		int total_think = (int)me->query_think();

		s += "力量："+format_game_number(total_str);
		if(heart_str>0)
			s += " §2(心法＋"+format_game_number(heart_str)+")§r";
		s += "\n  基础"+format_game_number(base_str)+
			"＋装备"+format_game_number(
				total_str-base_str-heart_str)+"\n";

		s += "敏捷："+format_game_number(total_dex);
		if(heart_dex>0)
			s += " §2(心法＋"+format_game_number(heart_dex)+")§r";
		s += "\n  基础"+format_game_number(base_dex)+
			"＋装备"+format_game_number(
				total_dex-base_dex-heart_dex)+"\n";

		s += "智力："+format_game_number(total_think);
		if(heart_think>0)
			s += " §2(心法＋"+format_game_number(heart_think)+")§r";
		s += "\n  基础"+format_game_number(base_think)+
			"＋装备"+format_game_number(
				total_think-base_think-heart_think)+"\n";
	}

	}
	
	tmp = me->query_equip_add("renxing");
	if(tmp){
		s += "韧性：+"+format_game_number(tmp)+"\n";
	}

	s += "幸运："+format_game_number(me->query_lunck());
	if(me->query_equip_add("lunck")>0)
		s += "＋"+format_game_number(me->query_equip_add("lunck"))+"\n";
	else
		s += "\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "闪避："+me->query_phy_dodge_str()+"%";
	tmp = me->query_danyao_add("attri_vice","dodge")+me->query_danyao_add("te_vice","dodge");
	if(tmp)
		s += "＋"+tmp+"%\n";
	else
		s += "\n";
	s += "命中："+me->query_phy_hitte_str()+"%";
	tmp = me->query_danyao_add("attri_vice","hitte")+me->query_danyao_add("te_vice","hitte");
	if(tmp)
		s += "＋"+tmp+"%\n";
	else
		s += "\n";
	s += "暴击："+me->query_phy_baoji_str()+"%";
	tmp = me->query_danyao_add("attri_vice","doub")+me->query_danyao_add("te_vice","doub");
	if(tmp)
		s += "＋"+tmp+"%\n";
	else
		s += "\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "火系法术抗性："+format_game_number((int)(me->query_equip_add("huoyan_defend")+me->query_equip_add("all_mofa_defend")))+"\n";
	s += "冰系法术抗性："+format_game_number((int)(me->query_equip_add("bingshuang_defend")+me->query_equip_add("all_mofa_defend")))+"\n";
	s += "风系法术抗性："+format_game_number((int)(me->query_equip_add("fengren_defend")+me->query_equip_add("all_mofa_defend")))+"\n";
	s += "毒系法术抗性："+format_game_number((int)(me->query_equip_add("dusu_defend")+me->query_equip_add("all_mofa_defend")))+"\n";
	s += "附加物理伤害："+
		format_game_number((int)me->query_equip_add("attack_all"))+"\n";
	s += "全系法术伤害："+
		format_game_number((int)me->query_equip_add("mofa_all"))+"\n";
	s += "附加物理穿透（无视防御伤害）："+
		format_game_number((int)me->query_equip_add("wulichuantou_add"))+"\n";
	s += "附加法术穿透（无视防御伤害）："+
		format_game_number((int)me->query_equip_add("mofachuantou_add"))+"\n";
	s += "附加闪避穿透："+
		sprintf("%0.2f",(float)me->query_equip_add("dodgechuantou_add")/10.0)+
		"%（普攻最高40%，物理技能最高60%）\n";
	//s += "全法术抗性："+me->query_equip_add("all_mofa_defend")+"\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
