#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string uid = me->query_name();
	object env=environment(me);
	string s = "";
	mapping alInfo = AUTO_LEARND->query_player_info(uid);
	if(alInfo)
	{
		s += alInfo["state_desc"] +"\n";
		if(!alInfo["state"])
		{
			s += "你的修炼已经完成，无需中断。\n";
		}
		else
		{
			s += "你的修炼尚未完成，确实要中断吗？\n";
			s += "[确定:_break_then_auto_learn_end_confirm]\n";
		}
	}
	else
	{
		s += "你的修炼已经完成了很久，或者你不在正确的位置\n";
	}
	s += "[返回:look]\n";
	write(s);
	return 1;
}
