#include <globals.h>
int main(string arg)
{
	string s = "";
	s += "你已经退出游戏，请返回。\n";
	s += "[url 返回首页:http://xd.dogstart.com]\n";
	write(s);
	this_player()->remove();
	return 1;
}
