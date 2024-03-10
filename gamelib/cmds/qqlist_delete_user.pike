#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	if(!arg) arg="";
	this_player()->qqlist_delete(arg);
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,"你已将该好友从好友列表删除。");
	return 1;
}
