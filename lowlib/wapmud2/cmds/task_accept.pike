//���ڽ������������
//��liaocheng��07/3/12�����
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
		s += npc->query_name_cn()+"��";
		int get_flag = TASKD->get_task(this_player(),taskid,npc);
		werror("----- get_flag =["+ get_flag+"]----\n");
		if(get_flag==1){
			s += TASKD->queryTaskAcceptWord(taskid)+"\n";
			s += "\n�����������"+TASKD->queryTaskName(taskid)+"\n";
		}
		else if(get_flag==2)
			s += "\n"+this_player()->query_name_cn()+"�������������˵̫Σ���ˣ��Ҳ��ܰ���������\n";
		else if(get_flag==3)
			s += "\n�����б��������޷����ܴ�����\n";
		else if(get_flag==4)
			s += "\nְҵ���Կ�~�����޷����ܴ�����\n";
		else if(get_flag==5)
			s += "\n���Ѿ����ܹ��˴�����\n";
		else if(get_flag==6)
			s += "\n���Ѿ���ɹ����������������ɣ�\n";
		else
			s +="\n�㲻�ܽ��ܴ�����\n";
	}
	s += "[����:look]\n";
	write(s);
	return 1;
}
