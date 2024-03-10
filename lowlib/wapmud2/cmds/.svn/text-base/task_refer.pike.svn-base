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
		int canRepeat = TASKD->query_task_isRepeat(taskid);
		if(!canRepeat && this_player()["/taskd/done"][taskid]){
			s += "你已经提交过了这个任务\n";
			//this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
			s += "[返回:look]\n";
			write(s);
			return 2;
		}
		else if(this_player()["/taskd/Cont"][taskid]){
			if(TASKD->isComplete(this_player(),taskid) == 0){
				s += "你未完成该任务\n";
				s += "[返回:look]\n";
				write(s);
				return 4;
			}
			else{
				s += npc->query_name_cn()+"：";
				s += TASKD->queryTaskCompleteWord(taskid)+"\n";
				s += "\n你完成了任务："+TASKD->queryTaskName(taskid)+"\n";
				s += TASKD->getTaskAward(this_player(),taskid);
				TASKD->clearTask(this_player(),taskid);
				s += "[返回:look]\n";
				write(s);
				return 1;
			}
		}
		else{
			s += "你现在没有这个任务\n";
			s += "[返回:look]\n";
			write(s);
			return 3;
		}
	}
	return 0;
}
