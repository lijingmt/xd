//用于接受任务后的输出
//由liaocheng于07/3/12日添加
#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	int taskid;
	string npcname = "";
	sscanf(arg,"%s %d",npcname,taskid);
	object npc = present(npcname,environment(this_player()));
	string s = "";
	if(npc){                                                                                                  
		s += npc->query_name_cn()+"：";
		int get_flag = TASKD->get_task(this_player(),taskid,npc);
		werror("----- get_flag =["+ get_flag+"]----\n");
		if(get_flag==1){
			s += TASKD->queryTaskAcceptWord(taskid)+"\n";
			s += "\n你接受了任务："+TASKD->queryTaskName(taskid)+"\n";
		}
		else if(get_flag==2)
			s += "\n"+this_player()->query_name_cn()+"，这任务对你来说太危险了，我不能把它交给你\n";
		else if(get_flag==3)
			s += "\n任务列表已满，无法接受此任务\n";
		else if(get_flag==4)
			s += "\n职业不对口~，你无法接受此任务\n";
		else if(get_flag==5)
			s += "\n你已经接受过了此任务\n";
		else if(get_flag==6)
			s += "\n你已经完成过该任务，明日再来吧！\n";
		else
			s +="\n你不能接受此任务\n";
	}
	s += "[返回:look]\n";
	write(s);
	return 1;
}
