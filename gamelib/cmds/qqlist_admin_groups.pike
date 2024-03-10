#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	this_player()->write_view(WAP_VIEWD["/qqlist_admin_groups"],this_player(),this_player(),arg);
	return 1;
}

