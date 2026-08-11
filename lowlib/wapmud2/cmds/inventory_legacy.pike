#include <command.h>
#include <wapmud2/include/wapmud2.h>

int main(string|zero arg)
{
	object me=this_player();
	if(!me)
		return 1;
	me->write_view(WAP_VIEWD["/inventory_legacy"],arg);
	return 1;
}
