#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string areaName = arg;
	string s = "";
	s += HOMED->banner_area(areaName) + "\n\n";
	s += "请选择你想要的地段:\n";
	s += HOMED->query_slot_for_sale(areaName);
	s += "\n[返回:popview]\n";
	s += "[返回游戏:look]\n"; 
	write(s);
	return 1;
}
