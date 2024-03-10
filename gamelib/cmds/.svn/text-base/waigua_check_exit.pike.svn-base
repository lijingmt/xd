#include <command.h>
#include <gamelib/include/gamelib.h>
//外挂警告，用户输入验证码的页面。
//arg = cd=code
int main(string arg)
{
	object me = this_player();
	string s = "";
	int code;
	if(1== 1){
		s += "验证通过，请点击离开。\n";
		string roomName = me->relife - "/gamelib/d/";//获得复活点所在的房间名
		me->command("qge74hye "+roomName);//传送到复活点
		call_out(waigua_remove,2);
		//s += "[离开这里:qge74hye beijing/zhengyangmen]\n";
		return 1;
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
