#include <command.h>
#include<wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();
	object ob = find_player(arg);
	string result = me->qurey_spy_info();
	me->write_view(WAP_VIEWD["/emote"],0,0,result);
	return 1;
}
