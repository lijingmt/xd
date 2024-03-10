#include <command.h>
#include <gamelib/include/gamelib.h>

//其他方式捐赠获取仙玉
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "其他方式捐赠获取仙玉\n";
	//s += "[短信捐赠获取仙玉:add_sms_fee]\n";
	//s += "[银行汇款捐赠获取玉石:add_big_fee]\n";
	s += "\n";
	s += "[返回仙玉妙坊:yushi_myzone]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
