#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string uid = me->query_name();
	object env=environment(me);
	string s = "";
	mapping singalInfo = AUTO_LEARND->query_player_info(uid);
	if(singalInfo)
	{
		s += singalInfo["state_desc"] +"\n";
		if(!singalInfo["state"])
		{
			s += "��������Ѿ���ɡ�\n";
		}
		else
		{
			s += "���������δ���\n";
			s += "[ˢ��:_break_then_auto_learn_check]\n";
		}
	}
	else
	{
			s += "�����������ɺܳ�ʱ�䣬�����㲻����ȷ��λ�á�\n";
	}
	s += "[����:look]\n";
	write(s);
	return 1;
}
