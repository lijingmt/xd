#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = room_name
int main(string arg)
{
	string s = "";
	object me=this_player();
	string room_name = arg;
	string fb_id = me->fb_id;
	//如果玩家在副本内离开队伍，那么他会被传送到复活点
	string leave_to = FBD->query_fb_leave_room(room_name);
	FBD->delete_fb_members(me->fb_id,me->query_name());
    if(leave_to != "")
		me->command("qge74hye "+leave_to);
	return 1;
}
