#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object ob;
	if(arg)
		ob = find_player(arg);
	if(ob)
		this_player()->write_view(WAP_VIEWD["/qqlist_user"],0,0,arg);
	else
		this_player()->write_view(WAP_VIEWD["/qqlist_user_notOnline"],0,0,arg);
	return 1;
}

