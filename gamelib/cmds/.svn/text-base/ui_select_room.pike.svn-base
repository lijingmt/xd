#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	if(arg){
		if(arg == "open")
			arg = "pub";
		me->roomchatid = arg;
	}
	me->command("look");
	return 1;
}
