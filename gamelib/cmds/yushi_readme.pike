#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//玉石玩家操作接口
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "捐赠获取仙玉说明：\n";
	s += "用户捐赠50元，即可获得5颗玲珑玉\n";
	s += "捐赠联络qq:1811117272\n";
	//s += "[神州行卡捐赠获取仙玉说明:szx_readme]\n";
	//s += me->query_mini_picture_url("decorate11")+"[短信捐赠获取仙玉说明:yushi_msg_readme]\n";
	//s += me->query_mini_picture_url("decorate11")+"[银行捐赠获取仙玉说明:add_big_fee_des]\n";
	s += "[返回:yushi_myzone]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
