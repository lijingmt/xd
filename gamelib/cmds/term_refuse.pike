#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "��ܾ��˼����������롣\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
