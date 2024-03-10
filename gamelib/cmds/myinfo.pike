#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "［人物属性］\n";
	s += "[［人物状态］:myhp]\n";
	s += "[［武器装备］:mytools]\n";
	
	s += "攻击强度："+me->query_low_attack_desc()+"-"+me->query_high_attack_desc()+"\n";
	s += "防御强度："+me->query_defend_power()+"\n";
	
	s += "生命力："+me->get_cur_life()+"/"+me->query_life_max()+"\n";
	s += "法力值："+me->get_cur_mofa()+"/"+me->query_mofa_max()+"\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "力量："+me->get_cur_str();
	int tmp = me->query_equip_add("str")+me->query_equip_add("all")+me->query_danyao_add("attri_base","str")+me->query_danyao_add("te_base","str")+me->query_danyao_add("home_base","str");
	if(tmp)
		s += "＋"+tmp+"\n";
	else
		s += "\n";
	
	s += "敏捷："+me->get_cur_dex();
	tmp = me->query_equip_add("dex")+me->query_equip_add("all")+me->query_danyao_add("attri_base","dex")+me->query_danyao_add("te_base","dex")+me->query_danyao_add("home_base","dex");
	if(tmp)
		s += "＋"+tmp+"\n";
	else
		s += "\n";

	s += "智力："+me->get_cur_think();
	tmp = me->query_equip_add("think")+me->query_equip_add("all")+me->query_danyao_add("attri_base","think")+me->query_danyao_add("te_base","think")+me->query_danyao_add("home_base","think") ;
	if(tmp)
		s += "＋"+tmp+"\n";
	else
		s += "\n";
	
	tmp = me->query_equip_add("renxing");
	if(tmp){
		s += "韧性：+"+tmp+"\n";
	}

	s += "幸运："+me->query_lunck(); 
	if(me->query_equip_add("lunck")>0)
		s += "＋"+me->query_equip_add("lunck")+"\n";
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
	s += "火系法术抗性："+(int)(me->query_equip_add("huoyan_defend")+me->query_equip_add("all_mofa_defend"))+"\n";
	s += "冰系法术抗性："+(int)(me->query_equip_add("bingshuang_defend")+me->query_equip_add("all_mofa_defend"))+"\n";
	s += "风系法术抗性："+(int)(me->query_equip_add("fengren_defend")+me->query_equip_add("all_mofa_defend"))+"\n";
	s += "毒系法术抗性："+(int)(me->query_equip_add("dusu_defend")+me->query_equip_add("all_mofa_defend"))+"\n";
	//s += "全法术抗性："+me->query_equip_add("all_mofa_defend")+"\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
