#include <command.h>
#include <gamelib/include/gamelib.h>

//��ʯ����
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "��ʯ����\n";
	s += "[������ʯ:yushi_degrade]\n";
	s += "[�ϳ���ʯ:yushi_update]\n";
	//s += me->query_mini_picture_url("decorate10")+"[�һ��������Ƴ���:fee_exchange_list]\n";
	s += "\n";
	s += "[���������:yushi_myzone]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
