#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string infancyType = arg;
	string s ="这里是神秘禁地\n\n";
	s += "一种神秘而祥和的气息包围着这里的一切。\n";
	s += HOMED->query_function_room_links();
	s += "\n[返回前厅:home_move main]\n";
	write(s);
	return 1;
}
