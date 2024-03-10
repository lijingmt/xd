#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string infancyName = "";
	string lifeType = "";
	int ind = 0;
	int count = 0;
	sscanf(arg,"%s %s %d %d",infancyName,lifeType,ind,count);
	string re = "";
	re += HOMED->life_add(infancyName,lifeType,ind,count);
	write(re);
	return 1;
}
