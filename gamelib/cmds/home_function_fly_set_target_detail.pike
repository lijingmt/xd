#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	object room = environment(me);
	string s = "\n";

	if(room->query_room_type()=="fb"||room->query_room_type()=="home"||room->query_room_type()=="city") //��ʾ����ڸ������߼�԰��
	{
		s += "��԰�������������еķ��䲻������й�������\n";
		s += "[����:look]\n";
	}
	else{	
		s += "��ȷ��Ҫ��"+ room->query_name_cn() +"����ļ�԰������\n\n";
		s += "[ȷ��:home_function_fly_set_target_confirm]\n";
		s += "[ȡ��:look]\n";
	}
	write(s);
	return 1;
}
