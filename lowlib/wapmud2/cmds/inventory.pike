#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s="";
	object me = this_player();
	NEWBIED->record_action(me,"inventory");
	me->write_view(WAP_VIEWD["/inventory"],arg);
	return 1;
}
