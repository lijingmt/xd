#include <command.h>
#include <gamelib/include/gamelib.h>
/*
会员升级详细页面
auther: evan
2008.07.18
*/
int main(string arg)
{
	object me = this_player();
	string s = "***会员升级***\n\n";
	int old_level = me->query_vip_flag();//当前级别
	int new_level = 0;//升级后的级别
	sscanf(arg,"%d",new_level);
	string new_vip_desc = VIPD->get_vip_desc(new_level);
	mapping vip_name = VIPD->get_vip_name_map();
	mapping vip_cost = VIPD->get_vip_cost_map();
	string new_desc = VIPD->get_vip_desc(new_level);
	s += vip_name[new_level] + "\n\n";
	s += new_desc+"\n";

	int state = VIPD->get_vip_state(me);
	int cost = ((int)vip_cost[new_level]-(int)vip_cost[old_level]);
	if(state==2||state==3)
	{
		cost=cost*6/10;//会员期限过半后，享受6折优惠
	}
	s += "你即将升级为"+vip_name[new_level]+",需要花费"+ YUSHID->get_yushi_for_desc(cost*10)+"\n\n";
	s += "[确认:vip_service_upgrade_confirm.pike "+new_level+" "+cost+"]\n";
	s += "[返回:vip_service_upgrade_list.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
