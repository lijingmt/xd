#include <command.h>
#include <gamelib/include/gamelib.h>
//����
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "����\n\n";
	s += "[��Ϸ����:msg_read player new]\n";
	s += "[�������а�:paihang_list account 1]\n";
	s += "[�ҵĺ���:my_qqlist]\n";
	s += "[��ǰ���:userlist]\n";
	s += "[��������:chatroom_list]\n";
	s += "[ת����Ӫ:race_change]\n";
	s += "[����:look]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
