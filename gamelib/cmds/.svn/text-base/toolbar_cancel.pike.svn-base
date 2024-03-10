#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = num
int main(string arg)
{
	int num=(int)arg;
	string s = "";
	if(this_player()->clean_toolbar(num)){
		s = "你已取消了快捷键"+(num+1)+"的设置\n";
	}
	else 
		s += "取消设置失败\n";
	s += "[返回:my_toolbar]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}

