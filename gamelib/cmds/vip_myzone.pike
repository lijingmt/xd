#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//会员优惠购物平台
int main(string arg)
{
	object me = this_player();
	string s = "";
	mapping(string:int) time = localtime(time());
	int hour = time["hour"];
	s += "**会员特供区**\n\n";
	s += "---免费区---\n";
	s += "[宝石:vip_myzone_free_list baoshi 1]\n";
	s += "[特药:vip_myzone_free_list teyao 1]\n\n";

	s += "---折扣区---\n";
	s += "[宝石:vip_myzone_off_list baoshi 1]\n";
	s += "[道具:vip_myzone_off_list other 1]\n";
	s += "[特药:vip_myzone_off_list teyao 1]\n";

	s += VIPD->get_vip_state_des(me);
	s += "\n[返回:yushi_myzone]\n";
	s += "\n[返回游戏:look]\n";
	write(s);
	return 1;
}
