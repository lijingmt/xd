//用于玩家查询已完成的任务
//由liaocheng于07/3/19日添加
#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	s += TASKD->queryTaskHistory(this_player());	
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
