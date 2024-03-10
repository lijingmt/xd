#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string infancyType = arg;
	string s = "请选择你要购买的物品:\n";
	s += HOMED->query_infancy(infancyType);
	s += "\n[返回:popview]\n";
	write(s);
	return 1;
}
