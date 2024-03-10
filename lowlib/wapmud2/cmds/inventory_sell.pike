#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	this_player()->write_view(WAP_VIEWD["/inventory_sell"]);
	return 1;
}


