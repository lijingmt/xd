#include <command.h>
#include <gamelib/include/gamelib.h>

//������ʽ������ȡ����
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "������ʽ������ȡ����\n";
	//s += "[���ž�����ȡ����:add_sms_fee]\n";
	//s += "[���л�������ȡ��ʯ:add_big_fee]\n";
	s += "\n";
	s += "[���������:yushi_myzone]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
