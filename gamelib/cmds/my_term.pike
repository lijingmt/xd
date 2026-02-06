#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "［队伍状态］\n";
	s += TERMD->query_termStatus(me->query_term(),me->query_name());
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
