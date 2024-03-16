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
	string s = "***会员优惠政策***\n\n";
	s += "0、享受一个月(30天)部分项目免费使用服务\n";
	s += "1、已获得会员资格玩家也可以花费一定玉石进行升级服务\n";
	s += "2、会员期过半之后，申请升级会员,将享受升级价格6折优惠\n";
	s += "3、会员期间续费可以享受9折优惠\n\n\n";

	s += VIPD->get_vip_state_des(me);

	s += "\n[返回:vip_service_list.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
