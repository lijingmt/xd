#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//�����Ź�
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "�ҵĹ���\n\n";
	s += "[����:home_dog_bury]\n";
	s += "[����:home_dog_resurrected]\n\n";
	s += "[����:look]\n";
	write(s);
	return 1;
}
