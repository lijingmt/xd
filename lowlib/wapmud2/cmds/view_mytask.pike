//用于玩家查询已接受的任务，并且提供了放弃任务的链接
//由liaocheng于07/3/14日添加
#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string playername="";
	string s = "";
	int taskid;
	int flag;
	sscanf(arg,"%d %d",taskid,flag);
	if(taskid){
		s += "任务名："+TASKD->queryTaskName(taskid)+"\n";
		s += "任务等级："+TASKD->queryTaskLevel(taskid)+"\n";
		if(TASKD->queryTaskProfe(taskid)!="")
			s +="职业："+TASKD->queryTaskProfe(taskid)+"\n";
		s += TASKD->queryTaskDesc(taskid)+"\n";
		s += "完成此任务，你将获得：\n";
		int money = TASKD->queryTaskMoney(taskid);
		string item = TASKD->queryTaskItem(taskid);
		if(money)
			s += " "+MUD_MONEYD->query_other_money_cn(money)+"\n";
		s += TASKD->queryTaskItem(taskid);
		
		if(flag){
			s += "\n"+TASKD->queryTaskProcess(this_player(),taskid);
			s += "[放弃任务:task_cancel "+taskid+"]\n";
		}
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	}
	return 1;
}
