#include <command.h>                                                                                                         
#include <gamelib/include/gamelib.h>

//�߼������鹺�����ָ��

int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "����ɹ���ĸ߼������飺\n";
	s += "\n";
	s += BUYD->get_book();
	s += "\n[����:yushi_myzone]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
