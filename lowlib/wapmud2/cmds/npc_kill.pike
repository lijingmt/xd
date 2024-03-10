#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,environment(this_object()),count);
	if(!ob)
		return 1;
	else if( ob&&ob->query_raceId()==this_object()->query_raceId() )
		return 1;
	this_object()->kill(name,count);
	return 1;
}
