#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string lifeType = "";
	int ind = 0;
	sscanf(arg,"%s %d",lifeType,ind);
	object me = this_player();
	object room = environment(me);
	string re = HOMED->query_life_detail(lifeType,ind);
	write(re);
	return 1;
}
