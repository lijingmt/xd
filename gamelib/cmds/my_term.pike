#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "�۶���״̬��\n";
	s += TERMD->query_termStatus(me->query_term(),me->query_name());
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
