//���û���д�µļ�԰����
#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	object me = this_player();
	if(me->query_home_path()&&me->query_home_path()!=""){
		s += "�������԰������[string na:...]\n";
		s += "[submit �ύ:home_redesc_confirm ...]\n";
	}
	else
		s += "�㻹û���Լ��ķ�����\n";
	s += "[����:look]\n";
	write(s);
	return 1;
}
