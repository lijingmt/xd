#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "�����˳��ĸ����飿\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	int rs = TERMD->leave_term(arg, me->query_name(), me->query_name_cn());
	switch(rs){
		case 0:
			//s += "�뿪����ʧ�ܣ�û�иö���\n";
			s += "���Ѿ��뿪����\n";
			me->set_term("noterm");
		break;
		case 1:
			s += "�ɹ��˳����顣\n";
            		//ˢ�¶���
            		TERMD->flush_term(me->query_term());  
		break;
		case 2:
			s += "�������Ƕӳ��������˳����飬���Խ�ɢ���飬��ת�ƶӳ���������Ա���˳����顣\n";
		break;
	}
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
