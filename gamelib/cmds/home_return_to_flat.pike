#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	object old_room = environment(me);
	string flatPath = arg;
	if(!old_room || !old_room->query_room_type ||
	   old_room->query_room_type()!="home" || !old_room->query_flatPath ||
	   flatPath!=(string)old_room->query_flatPath()){
		write("离开目标校验失败。\n[确定:look]\n");
		return 1;
	}
	int moved;
	mixed move_err = catch { moved = me->move(flatPath); };
	if(move_err || !moved){
		write("暂时无法离开家园，请稍后重试。\n[确定:look]\n");
		return 1;
	}
	HOMED->clear_user(me);
	me->reset_view();
	me->command("look");
	return 1;
}
