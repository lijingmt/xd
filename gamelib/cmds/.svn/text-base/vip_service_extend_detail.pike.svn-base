#include <command.h>
#include <gamelib/include/gamelib.h>
/*
申请入会详情页面
auther: evan
2008.07.16
*/
int main(string arg)
{
	object me = this_player();
	string s = "***会员续费***\n\n";
	s += VIPD->get_vip_state_des_withoutlink(me);
	int state = VIPD->get_vip_state(me);
	if(state)//如果是会员
	{
		int level = me->query_vip_flag();
		int vip_cost = VIPD->get_vip_cost(level);
		vip_cost = vip_cost*9/10;//续费9折优惠
		string cost_des = YUSHID->get_yushi_for_desc(vip_cost*10);
		string vip_name = VIPD->get_vip_name(level);
		string vip_desc = VIPD->get_vip_desc(level);
		s += "你是"+vip_name+",现在续费享受9折优惠，只需"+cost_des+"\n(注意：续费将使会员资格在原有基础上顺延30天)\n"; 
		s += "[续费:vip_service_extend_confirm "+ vip_cost +"]\n\n";
	}
	else//非会员则给出申请提示
	{
		s += VIPD->get_vip_state_des(me);
	}
	s += "[返回:vip_service_list.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
