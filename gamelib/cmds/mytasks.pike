#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	string s = "";
	s += TASKD->queryMyTasks(this_player());
	s += "\n[返回游戏:look]\n";
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
