#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	object env=environment(me);
	object master;
	string s = "";
	me->wakeup_from_auto_learn();
	s += AUTO_LEARND->clear_user(me);
	me->write_view_tmp(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
