#include <command.h>
#include <gamelib/include/gamelib.h>

//��������
int main(string arg)
{
	object me = this_player();
	string s = "";
	string masterId = me->query_name();
	s += HOMED->get_past_time_items(masterId);
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
