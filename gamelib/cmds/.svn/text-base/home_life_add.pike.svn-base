#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string lifeType = "";
	int ind = 0;
	sscanf(arg,"%s %d",lifeType,ind);
	object me = this_player();
	object room = environment(me);
	string re = "";
	re += HOMED->query_life_addList(lifeType,ind);
	write(re);
	return 1;
}
