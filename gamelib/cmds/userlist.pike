#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	this_player()->write_view(WAP_VIEWD["/user_list"]);
	return 1;
}

