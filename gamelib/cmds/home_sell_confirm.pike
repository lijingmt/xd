#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string homeName = "";
	int yushi = 0;
	int money = 0;
	string s = "";
	sscanf(arg,"%s %d %d",homeName,yushi,money);
	if(HOMED->if_have_home(me->query_name()))
	{
		if(HOMED->is_cleared(homeName))
		{
			s += HOMED->sell_confirm(homeName,yushi,money);
		}
		else
		{
			s += "你的家中还有访客，暂时不能卖出你的房产。\n";
		}
	}
	else
		s += "你现在没有房产\n";
	s += "\n[返回游戏:look]\n"; 
	write(s);
	return 1;
}
