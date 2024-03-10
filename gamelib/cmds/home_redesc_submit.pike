//新用户填写新的家园描述
#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	object me = this_player();
	if(me->query_home_path()&&me->query_home_path()!=""){
		s += "请输入家园描述：[string na:...]\n";
		s += "[submit 提交:home_redesc_confirm ...]\n";
	}
	else
		s += "你还没有自己的房产。\n";
	s += "[返回:look]\n";
	write(s);
	return 1;
}
