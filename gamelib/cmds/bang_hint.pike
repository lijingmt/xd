#include <command.h>
#include <gamelib/include/gamelib.h>
//�������ɽ������


int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "��������! ��׼��������?\n";
	s += "1.�ﵽ35��\n";
	s += "2.���\"������������\"\n";
	s += "3.��Ҫ��ʯ1����������\n";
	s += "4.��Ҫ���1000��\n";
	s += "\n";
	s += "��������, ����������?\n";
	s += "[����, ��Ҫ��������:bang_create]\n";
	s += "[��Ҫ��׼��׼��:look]\n";
	s += "\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}


