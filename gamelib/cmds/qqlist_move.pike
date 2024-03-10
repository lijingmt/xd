#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s,group;
	s=arg;
	string t = "";
	sscanf(arg,"%s %s",s,group);
	if(group==0){
		t="组名不能为空，请返回重新选择。\n";
	}
	else{
		t = this_player()->qqlist_group_insert(s,group)+"\n";
	}
	t+="[返回:my_qqlist]\n";
	t+="[返回游戏:look]\n";
	write(t);
	return 1;
}
