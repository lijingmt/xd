#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	if(!arg) 
		arg="";
	int t = this_player()->qqlist_group_delete(arg);
	if(t)
		s += "操作已成功，请返回。\n";
	else
		s += "操作失败，请返回重试。\n";
	s += "[返回:my_qqlist]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
