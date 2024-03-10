#include <command.h>
#include <gamelib/include/gamelib.h>
//外挂警告，用户输入验证码的页面。
//arg = cd=code
int main(string arg)
{
	object me = this_player();
	string s = "";
	int code;
	sscanf(arg,"cd=%d",code);
	int my_code = (int)me["/plus/check_code"];
	if(code == my_code){
		s += "验证通过，请点击离开。\n";
			s += "[离开这里:waigua_check_exit]\n";
			//	me->command("qge74hye beijing/zhengyangmen");   //小黑屋
			//	call_out(waigua_remove,2);
	}
	else{
		s += "验证码输入有误，请重新输入。\n";
		s += "[重新输入:look]\n";
	}
	write(s);
	return 1;
}
void waigua_remove()
{
	this_player()->remove();
	return;
}
