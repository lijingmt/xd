//用于玩家删除已接受的任务
//由liaocheng于07/3/14日添加
#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	int taskid = (int)arg;
	string s = "";
	if(taskid&&this_player()["/taskd/Cont"][taskid]){
		TASKD->cancelTask(this_player(),taskid);
		s += "你放弃了任务："+TASKD->queryTaskName(taskid)+"\n";
		s += "[返回:look]\n";
		write(s);
	}
	else{
		s +="你没有这个任务。\n";
		s += "[返回:look]\n";
		write(s);
	}
	return 1;
}
