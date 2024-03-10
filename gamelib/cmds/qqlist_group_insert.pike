#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	this_player()->write_view(WAP_VIEWD["/qqlist_group_insert"],0,0,arg);
	return 1;
}

