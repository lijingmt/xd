#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	if(!LOGICALZONED->can_user_action("home",me->query_name(),arg)){
		write("逻辑分区隔离中，无法访问该玩家的家园。\n[确认:look]\n");
		return 1;
	}
	object room = HOMED->query_room_by_masterId(arg,"main");
	string s = "";
	if(room){
		if(!HOMED->move_user_to_home(me,room)){
			write("该家园当前位于其他地图节点，请稍后重试。\n[确认:look]\n");
			return 1;
		}
		me->reset_view(WAP_VIEWD["/home"]);
		me->write_view();
		return 1;
	}
	else{
		s += "他家好像还在装修，稍后再来吧\n";
		s += "\n[确认:look]\n";
		write(s);
		return 1;
	}
	return 1;
}
