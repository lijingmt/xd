#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "你拒绝了加入队伍的邀请。\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
