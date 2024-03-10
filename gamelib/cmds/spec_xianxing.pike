#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	int flag;
	object me=this_player();
	if(me->in_combat){
		me->hind = 0;
		me->command("attack");
		return 1;
	}
	else{
			me->hind = 0;
			me->reset_view();
			me->command("look");
	}
	return 1;
}
