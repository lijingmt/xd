#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//玉石玩家操作接口
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "仙道玉石系统分为五个等级，分别是：\n";
	s += "【玉】碎玉\n";
	s += "【玉】仙缘玉\n";
	s += "【玉】玲珑玉\n";
	s += "【玉】碧玺玉\n";
	s += "【玉】玄天宝玉\n";
	s += "玩家每次花费1元可以购买一块【玉】仙缘玉\n";
	s += "玉石随等级提高价值\n";
	s += "1块【玉】仙缘玉可以打碎成为10块【玉】碎玉\n";
	s += "10块【玉】仙缘玉可以合成为1块【玉】玲珑玉\n";
	s += "以此类推\n";
	s += "[返回:yushi_myzone]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
