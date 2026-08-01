#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object ob;
	if(arg)
		ob = find_player(arg);
	if(ob && !LOGICALZONED->can_interact(this_player(),ob))
		ob = 0;
	if(ob)
		this_player()->write_view(WAP_VIEWD["/qqlist_user"],0,0,arg);
	else
		this_player()->write_view(WAP_VIEWD["/qqlist_user_notOnline"],0,0,arg);
	return 1;
}
