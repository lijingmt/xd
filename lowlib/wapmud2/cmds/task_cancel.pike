//�������ɾ���ѽ��ܵ�����
//��liaocheng��07/3/14�����
#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	int taskid = (int)arg;
	string s = "";
	if(taskid&&this_player()["/taskd/Cont"][taskid]){
		TASKD->cancelTask(this_player(),taskid);
		s += "�����������"+TASKD->queryTaskName(taskid)+"\n";
		s += "[����:look]\n";
		write(s);
	}
	else{
		s +="��û���������\n";
		s += "[����:look]\n";
		write(s);
	}
	return 1;
}
