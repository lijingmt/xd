#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string infancyName = "";
	string lifeType = "";
	int ind = 0;
	int count = 0;
	sscanf(arg,"%s %s %d %d",infancyName,lifeType,ind,count);
	object me = this_player();
	object room = environment(me);
	string re = "";
	re += HOMED->query_infancy_detail(infancyName,lifeType,ind,count);
	write(re);
	return 1;
}
