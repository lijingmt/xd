#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string flatPath = arg;
	me->inhome_pos = "";
	me->move(flatPath);
	me->reset_view();
	me->command("look");
	return 1;
}
