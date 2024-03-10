#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string s = "";
	s += environment(this_player())->view_goods_list();
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
