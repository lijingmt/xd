#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	object env = environment(this_player());
	string s = "";
	if(env->query_room_type() == "home")//防止玩家使用"返回"按钮带来的错误
	{ 
		string homeId = env->query_homeId();
		object room = HOMED->query_room(arg,homeId);
		if(room){
			me->move(room);
			me->reset_view(WAP_VIEWD["/home"]);                                                                      
			me->write_view();
			return 1;
		}
		else{
			s += "他家已经被变卖或者你不在正确的位置。\n";
			s += "\n[确定:look]\n";
			write(s);
			return 1;
		}
	}
	else{
		s += "你不在正确的位置。\n";
		s += "\n[确定:look]\n";
		write(s);
		return 1;
	}
	return 1;
}
