#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string areaName = arg;
	string s = "";
	s += HOMED->banner_area(areaName) + "\n\n";
	s += "��ѡ������Ҫ�ĵض�:\n";
	s += HOMED->query_slot_for_sale(areaName);
	s += "\n[����:popview]\n";
	s += "[������Ϸ:look]\n"; 
	write(s);
	return 1;
}
