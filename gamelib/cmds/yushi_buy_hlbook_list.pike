#include <command.h>                                                                                                         
#include <gamelib/include/gamelib.h>

//高级技能书购买调用指令

int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "今天可购买的高级技能书：\n";
	s += "\n";
	s += BUYD->get_book();
	s += "\n[返回:yushi_myzone]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
