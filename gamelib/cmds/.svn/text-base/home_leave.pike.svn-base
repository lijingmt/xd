#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	object room = environment(me);
	string s = "";
	string slotName = "";
	string flatName = "";
	sscanf(arg,"%s %s",slotName,flatName);
	s += "确实要离开这里吗？\n";
	s += "[确定:home_display_home "+ slotName +" "+flatName +" 1]\n";//1 表示是从home中返回到home选择页面
	s += "[返回:look]\n";
	write(s);
	return 1;
}
