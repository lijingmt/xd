#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object player=this_player();
	string s = "���Ѿ��ɹ����÷������ó�Ϊ����㣬�뷵�ء�\n";
	if(arg)
		player->relife=arg;
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
