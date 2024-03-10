#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "[添加房间:home_functionroom_buy_list home_base]\n";
		s += "[变卖房间:home_functionroom_remind home_base]\n";
	}
	/*
	if(HOMED->if_can_buy_functionroom(me->query_name())){
		s += "您所拥有的功能房间数量已达到上限，不能再添加别的功能房间\n";
		s += "\n[返回:popview]\n";
		write(s);
		return 1;
	}
	*/
	else{
		s += HOMED->query_function_room_for_sale(arg);
	}
	s += "\n[返回:popview]\n";
	write(s);
	return 1;
}
