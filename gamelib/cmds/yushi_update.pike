#include <command.h>
#include <gamelib/include/gamelib.h>
//合成玉石调用的指令，列出玩家可以合成的玉石列表
int main(string arg)
{
	object me = this_player();
	string s = "目前你能合成的玉石有：\n";
	s += YUSHID->query_can_update(me);
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
