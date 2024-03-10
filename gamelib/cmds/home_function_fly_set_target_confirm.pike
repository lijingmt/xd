#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	object room = environment(me);
	string s = "\n\n";
	if(HOMED->if_have_home(me->query_name()))
	{
		if(!ITEMSD->if_have_enough(me,"chuansongshenfu")) 
		{
			s += "你没有传送神符，可以在杂货商人处购买到。\n";
		}
		else
		{
			s +=  HOMED->set_fly_target(me,room);

		}
	}
	else
	{
		s += "你现在还没有家园，不能完成该操作\n";

	}
	s += "\n[返回:look]\n";
	write(s);
	return 1;
}
