#include <command.h>
#include <gamelib/include/gamelib.h>

/******************************************************************
*�鿴����
*author caijie
*2008/07/16
*arg = id �������ڴ��е�������
*����
*arg =  type(player or admin) more(old or    new)
*            ���     ����Ա       ��ʷ����  ���¹���
*****************************************************************/

int main(string arg)
{
	object me = this_object();
	string s = "";
	string type = "";	//�����Ƿ��ǹ���Ա
	string more = "";	//�����¹�������ʷ�����ж�
	if(sscanf(arg,"%s %s",type,more)!=2){
		int id = (int)arg;	
		s += MSGD->get_old_msg("type",id);
		s += "\n";
		s += "[����:popview]\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	if(more=="old"){
		s += MSGD->get_old_msg(type);
	}
	else{
		s += MSGD->get_new_msg();
		if(!sizeof(s)){
			s += "Ŀǰû�й���\n";
		}
		else {
			s += "-----------\n";
			s += "[�鿴��ʷ����:msg_read player old]\n";
		}
	}
	s += "\n";
	s += "[����:popview]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
