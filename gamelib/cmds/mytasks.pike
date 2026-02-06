#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	s += TASKD->queryMyTasks(this_player());
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
