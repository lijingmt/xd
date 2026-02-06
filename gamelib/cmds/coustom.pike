#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	if(this_player()->in_combat)
		this_player()->write_view(WAP_VIEWD["/look"]);
	else
		this_player()->write_view(WAP_VIEWD["/coustom"]);
	return 1;
}

