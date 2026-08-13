#include <command.h>
#include <wapmud2/include/wapmud2.h>

int main(string|zero arg)
{
	object me=this_player();
	if(!me)
		return 1;
	write(me->view_inventory_search(arg));
	return 1;
}
