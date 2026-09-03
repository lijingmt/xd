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
	s += "力量："+format_game_number(me->get_cur_str());
	int tmp = me->query_equip_add("str")+me->query_equip_add("all")+me->query_danyao_add("attri_base","str")+me->query_danyao_add("te_base","str")+me->query_danyao_add("home_base","str");
	if(tmp)
		s += "＋"+format_game_number(tmp)+"\n";
	else
		s += "\n";
	
	s += "敏捷："+format_game_number(me->get_cur_dex());
	tmp = me->query_equip_add("dex")+me->query_equip_add("all")+me->query_danyao_add("attri_base","dex")+me->query_danyao_add("te_base","dex")+me->query_danyao_add("home_base","dex");
	if(tmp)
		s += "＋"+format_game_number(tmp)+"\n";
	else
		s += "\n";

	s += "智力："+format_game_number(me->get_cur_think());
	tmp = me->query_equip_add("think")+me->query_equip_add("all")+me->query_danyao_add("attri_base","think")+me->query_danyao_add("te_base","think")+me->query_danyao_add("home_base","think") ;
	if(tmp)
		s += "＋"+format_game_number(tmp)+"\n";
	else
		s += "\n";

	// 心法（无相/太极）：结算时把最高项按比例加成另外两系。战斗与
	// 客户端数值已包含（query_str/dex/think），但文字面板此前不
	// 显示，玩家误以为"没有效果"。这里明确展示当前生效值。
	{
		string profe = functionp(me->query_profeId) ?
			(string)me->query_profeId() : "";
		if(profe=="wuxiang" || profe=="taiji"){
			int percent = profe=="taiji" ? 65 : 50;
			int hb_dex = (int)me->query_taiji_heart_bonus("dex")+
				(int)me->query_wuxiang_heart_bonus("dex");
			int hb_think = (int)me->query_taiji_heart_bonus("think")+
				(int)me->query_wuxiang_heart_bonus("think");
			int hb_str = (int)me->query_taiji_heart_bonus("str")+
				(int)me->query_wuxiang_heart_bonus("str");
			s += "【"+(profe=="taiji"?"太极":"无相")+"心法】最高总属性(含装备)×"+
				percent+"%加成另两系：";
			if(hb_str)
				s += "力量＋"+format_game_number(hb_str)+" ";
			if(hb_dex)
				s += "敏捷＋"+format_game_number(hb_dex)+" ";
			if(hb_think)
				s += "智力＋"+format_game_number(hb_think)+" ";
			s += "（战斗结算已生效，不计入装备门槛）\n";
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
