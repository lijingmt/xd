#include <command.h>
#include <gamelib/include/gamelib.h>
//安全码说明

int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "[安全码的作用:bandpsw_readme effect]\n";
		//werror("----me->bandpswd="+me->bandpswd+"----\n");
		if(me->bandpswd && sizeof(me->bandpswd))
			;
		else
			s += "[设定安全码:set_bandpsw]\n";
		//s += me->query_bandpswd();
		s += "[修改安全码:bandpsw_change]\n";
		s += "\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	//安全码的作用
	s += "安全码的作用\n";
	s += "\n";
	s += "玩家在帐号被盗用之后，能够利用此安全码第一时间锁定帐号，降低个人损失\n";
	s += "冻结后，被冻结帐号将不能再进行登录，当前在线玩家将会被直接强制下线\n";
	s += "解除冻结或者忘记安全码，需要玩家用绑定手机拨打客服电话，由游戏客服人员进行相关操作\n";
	s += "客服电话：(010)58621742\n";
	s += "\n";
	s += "[返回:bandpsw_readme]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
