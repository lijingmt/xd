#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	string s = "";
	object me = this_player();
	object|zero room = HOMED->query_home_by_path(arg);
	if(room && !LOGICALZONED->can_user_action("home",
	   me->query_name(),room->query_masterId()))
		room = 0;
	if(room){
		me->set_inhome_pos(room->query_masterId());
		me->move(room);
		HOMED->add_user(me->query_name());
		me->reset_view(WAP_VIEWD["/home"]);
		me->write_view();
		return 1;
	}
	else{
		s += "他的地方有些问题，豪宅已经被官方查封了。\n";
		s += "\n[确认:look]\n";
		write(s);
		return 1;
	}
	return 1;
}
