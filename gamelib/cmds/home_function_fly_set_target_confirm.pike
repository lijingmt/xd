#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	object room = environment(me);
	string s = "\n\n";
	if(HOMED->if_have_home(me->query_name()))
	{
		if(!ITEMSD->if_have_enough(me,"chuansongshenfu")) 
		{
			s += "��û�д���������������ӻ����˴����򵽡�\n";
		}
		else
		{
			s +=  HOMED->set_fly_target(me,room);

		}
	}
	else
	{
		s += "�����ڻ�û�м�԰��������ɸò���\n";

	}
	s += "\n[����:look]\n";
	write(s);
	return 1;
}
