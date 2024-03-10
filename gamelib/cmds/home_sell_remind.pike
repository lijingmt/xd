#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!HOMED->if_have_home(me->query_name()))
	{
		s += "你还没有地产，空手套白狼在这里可行不通\n";
	}
	else
	{
		s += HOMED->query_sell_info();
	}
	s += "[返回游戏:look]\n"; 
	write(s);
	return 1;
}
