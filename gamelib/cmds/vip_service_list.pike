#include <command.h>
#include <gamelib/include/gamelib.h>
/*
会员服务首页
author: evan
2008.07.16
*/
int main(string|zero arg)
{
	object me = this_player();
	string s = "***会员服务***\n\n";
	s +="[会员优惠政策:vip_service_show]\n\n";
	s += VIPD->get_level_limit_des(me)+"\n";
	s += VIPD->get_level_limit_action_links(me)+"\n";
	s += VIPD->get_vip_state_des(me);
	if(PROFESSIONVIPD->is_supported_profession(me->query_profeId()))
		s += "\n[查看本职业会员助手:profession_assistant]\n";
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
