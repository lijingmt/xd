#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object player=this_player();
	string s = "你已经成功将该房间设置成为复活点，请返回。\n";
	if(arg)
		player->relife=arg;
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
