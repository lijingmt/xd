//������Ҳ�ѯ�ѽ��ܵ����񣬲����ṩ�˷������������
//��liaocheng��07/3/14�����
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
		s += "��������"+TASKD->queryTaskName(taskid)+"\n";
		s += "����ȼ���"+TASKD->queryTaskLevel(taskid)+"\n";
		if(TASKD->queryTaskProfe(taskid)!="")
			s +="ְҵ��"+TASKD->queryTaskProfe(taskid)+"\n";
		s += TASKD->queryTaskDesc(taskid)+"\n";
		s += "��ɴ������㽫��ã�\n";
		int money = TASKD->queryTaskMoney(taskid);
		string item = TASKD->queryTaskItem(taskid);
		if(money)
			s += " "+MUD_MONEYD->query_other_money_cn(money)+"\n";
		s += TASKD->queryTaskItem(taskid);
		
		if(flag){
			s += "\n"+TASKD->queryTaskProcess(this_player(),taskid);
			s += "[��������:task_cancel "+taskid+"]\n";
		}
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	}
	return 1;
}
