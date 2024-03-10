#include <command.h>
#include <gamelib/include/gamelib.h>
/*
会员服务首页
auther: evan
2008.07.16
*/
int main(string arg)
{
	object me = this_player();
	string s = "***会员服务***\n\n";
	s +="[会员优惠政策:vip_service_show]\n\n";
	s += VIPD->get_vip_state_des(me);
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
