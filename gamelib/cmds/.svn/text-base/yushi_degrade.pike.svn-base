#include <command.h>
#include <gamelib/include/gamelib.h>
//打碎玉石调用的指令，列出玩家可以打碎的玉石列表
int main(string arg)
{
	object me = this_player();
	string s = "目前你能打碎的玉石有：\n";
	s += YUSHID->query_can_degrade(me);
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
