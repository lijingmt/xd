#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "�����ɢ�ĸ����飿\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	int rs = TERMD->destory_term(arg, me->query_name());
	switch(rs){
		case 0:
			s += "��ɢʧ�ܣ�û�иö���\n";
		break;
		case 1:
			s += "�ɹ���ɢ���顣\n";
            //ˢ�¶���
            TERMD->flush_term(me->query_term());  
		break;
		case 2:
			s += "��ɢʧ��,δ�ҵ��ö��顣\n";
		break;
		case 3:
			s += "��ɢʧ��,δ�ҵ��ö��顣\n";
		break;
		case 4:
			s += "�Ƕӳ�Ȩ�ޣ����ܽ�ɢ����\n";
		break;
	}
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
