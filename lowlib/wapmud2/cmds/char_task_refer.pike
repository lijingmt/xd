//���ڲ�ѯ�ύ������
//��liaocheng��07/3/12�����
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
		s += npc->query_name_cn()+"��";
		s += TASKD->queryTaskPromptWord(taskid)+"\n";
		s += "��������"+TASKD->queryTaskName(taskid)+"\n";
		s += "����ȼ���"+TASKD->queryTaskLevel(taskid)+"\n";
		if(TASKD->queryTaskProfe(taskid)!="")
			s +="ְҵ��"+TASKD->queryTaskProfe(taskid)+"\n";
		s += TASKD->queryTaskDesc(taskid)+"\n";
		s += "\n��ɴ������㽫��ã�\n";
		int money = TASKD->queryTaskMoney(taskid);
		if(money)
			s += " "+MUD_MONEYD->query_other_money_cn(money)+"\n";
		s += TASKD->queryTaskItem(taskid);
		
		if(TASKD->isComplete(this_player(),taskid)){
			s += "[�ύ����:task_refer "+arg+"]\n";
		}
		else
			s +="��δ��ɸ�����\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	}
	return 1;
}
