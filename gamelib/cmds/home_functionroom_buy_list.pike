#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "[��ӷ���:home_functionroom_buy_list home_base]\n";
		s += "[��������:home_functionroom_remind home_base]\n";
	}
	/*
	if(HOMED->if_can_buy_functionroom(me->query_name())){
		s += "����ӵ�еĹ��ܷ��������Ѵﵽ���ޣ���������ӱ�Ĺ��ܷ���\n";
		s += "\n[����:popview]\n";
		write(s);
		return 1;
	}
	*/
	else{
		s += HOMED->query_function_room_for_sale(arg);
	}
	s += "\n[����:popview]\n";
	write(s);
	return 1;
}
