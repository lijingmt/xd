#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	object env = environment(this_player());
	string s = "";
	if(env->query_room_type() == "home")//��ֹ���ʹ��"����"��ť�����Ĵ���
	{ 
		string homeId = env->query_homeId();
		object room = HOMED->query_room(arg,homeId);
		if(room){
			me->move(room);
			me->reset_view(WAP_VIEWD["/home"]);                                                                      
			me->write_view();
			return 1;
		}
		else{
			s += "�����Ѿ������������㲻����ȷ��λ�á�\n";
			s += "\n[ȷ��:look]\n";
			write(s);
			return 1;
		}
	}
	else{
		s += "�㲻����ȷ��λ�á�\n";
		s += "\n[ȷ��:look]\n";
		write(s);
		return 1;
	}
	return 1;
}
