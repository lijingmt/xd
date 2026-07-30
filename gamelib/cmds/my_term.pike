#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	NEWBIED->record_action(me,"team");
	s += "七星阵状：况\n";
	s += TERMD->query_termStatus(me->query_term(),me->query_name());
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
