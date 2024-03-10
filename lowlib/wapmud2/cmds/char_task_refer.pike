//用于查询提交的任务
//由liaocheng于07/3/12日添加
#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	int taskid;
	string npcname="";
	sscanf(arg,"%s %d",npcname,taskid);	
	string s = "";
	object npc=present(npcname,environment(this_player()));
	if(taskid&&npc){
		s += npc->query_name_cn()+"：";
		s += TASKD->queryTaskPromptWord(taskid)+"\n";
		s += "任务名："+TASKD->queryTaskName(taskid)+"\n";
		s += "任务等级："+TASKD->queryTaskLevel(taskid)+"\n";
		if(TASKD->queryTaskProfe(taskid)!="")
			s +="职业："+TASKD->queryTaskProfe(taskid)+"\n";
		s += TASKD->queryTaskDesc(taskid)+"\n";
		s += "\n完成此任务，你将获得：\n";
		int money = TASKD->queryTaskMoney(taskid);
		if(money)
			s += " "+MUD_MONEYD->query_other_money_cn(money)+"\n";
		s += TASKD->queryTaskItem(taskid);
		
		if(TASKD->isComplete(this_player(),taskid)){
			s += "[提交任务:task_refer "+arg+"]\n";
		}
		else
			s +="你未完成该任务\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	}
	return 1;
}
