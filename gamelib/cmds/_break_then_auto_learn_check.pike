#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string uid = me->query_name();
	object env=environment(me);
	string s = "";
	mapping singalInfo = AUTO_LEARND->query_player_info(uid);
	if(singalInfo)
	{
		s += singalInfo["state_desc"] +"\n";
		if(!singalInfo["state"])
		{
			s += "你的修炼已经完成。\n";
		}
		else
		{
			s += "你的修炼尚未完成\n";
			s += "[刷新:_break_then_auto_learn_check]\n";
		}
	}
	else
	{
			s += "你的修炼已完成很长时间，或者你不在正确的位置。\n";
	}
	s += "[返回:look]\n";
	write(s);
	return 1;
}
