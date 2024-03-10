#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	if(!arg)
	{
		this_player()->write_view(WAP_VIEWD["/inventory_daoju_package"]);
		return 1;
	}
	return 1;
}
