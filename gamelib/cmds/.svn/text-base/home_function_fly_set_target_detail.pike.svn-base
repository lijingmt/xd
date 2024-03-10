#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	object room = environment(me);
	string s = "\n";

	if(room->query_room_type()=="fb"||room->query_room_type()=="home"||room->query_room_type()=="city") //表示玩家在副本或者家园中
	{
		s += "家园、副本和主城中的房间不允许进行关联操作\n";
		s += "[返回:look]\n";
	}
	else{	
		s += "你确认要将"+ room->query_name_cn() +"与你的家园关联吗？\n\n";
		s += "[确定:home_function_fly_set_target_confirm]\n";
		s += "[取消:look]\n";
	}
	write(s);
	return 1;
}
