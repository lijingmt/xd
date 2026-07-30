#include <command.h>
#include <gamelib/include/gamelib.h>

#define AUTOFIGHTD ((object)(ROOT "/gamelib/single/daemons/autofightd"))

int main(string|zero arg)
{
	object me;
	me = this_player();
	if(!me)
		return 1;
	AUTOFIGHTD->stop_autofight(me);
	tell_object(me,"自动挂机已停止。\n");
	me->command("look");
	return 1;
}
