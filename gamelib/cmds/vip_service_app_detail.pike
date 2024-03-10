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
	string s = "***会员申请***\n\n";
	int level = 0;
	sscanf(arg,"%d",level);
	string vip_name = VIPD->get_vip_name(level);
	string vip_desc = VIPD->get_vip_desc(level);
	int vip_cost = VIPD->get_vip_cost(level);
	s += vip_name + "\n\n";
	s += vip_desc + "\n\n";
	s += "需要"+ YUSHID->get_yushi_for_desc(vip_cost*10)+"\n"; 
	s += "[申请:vip_service_app_confirm.pike "+level+"]\n\n";
	s += "[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
