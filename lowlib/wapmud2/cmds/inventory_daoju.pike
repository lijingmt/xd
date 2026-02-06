#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string s="";
	object me = this_player();
	if(!arg){
		me->write_view(WAP_VIEWD["/inventory_daoju"]);
		return 1;
	}
	return 1;
}


