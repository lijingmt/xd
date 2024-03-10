#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	if(arg!="null"){
		me->user_mid=arg;
	}
	return 1;
}
