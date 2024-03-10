#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	string f_room_name = arg;
	if(!HOMED->if_have_home(me->query_name()))
	{
		s += "你还没有地产，空手套白狼在这里可行不通\n";
	}
	else
	{
		//判断该功能房间是否存在
		if(!HOMED->if_have_function_room(f_room_name)){
			//该家园没有这个房间
			s += "你没有这样的房间\n";
		}
		else if(f_room_name == "feitianxiaowu"){
			s += "飞天小屋不能变卖\n";
		}
		else{
			s += HOMED->query_sell_functionroom_info(f_room_name);
		}
	}
	s += "[返回:home_functionroom_remind home_base]\n";
	s += "[返回游戏:look]\n"; 
	write(s);
	return 1;
}
