#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	string s = "";
	NEWBIED->record_action(this_player(),"tasks");
	s += "§g【每日修行】§r [签到、目标与活跃宝箱:daily]\n";
	s += TASKD->queryMyTasks(this_player());
	s += "\n[返回游戏:look]\n";
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
