#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!HOMED->if_have_home(me->query_name()))
	{
		s += "�㻹û�еز��������װ�����������в�ͨ\n";
	}
	else
	{
		s += HOMED->get_sell_functionroom_list(arg);
	}
	s += "\n[������Ϸ:look]\n"; 
	write(s);
	return 1;
}
