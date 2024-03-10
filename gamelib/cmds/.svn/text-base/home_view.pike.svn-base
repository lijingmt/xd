#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	object me = this_player();
	object room = HOMED->query_home_by_path(arg);
	if(room){
		me->set_inhome_pos(room->query_masterId());
		me->move(room);
		HOMED->add_user(me->query_name());
		me->reset_view(WAP_VIEWD["/home"]);                                                                      
		me->write_view();
		return 1;
	}
	else{
		s += "他家的地契有些问题，房屋已经暂时被官府查封了！\n";
		s += "\n[确定:look]\n";
		write(s);
		return 1;
	}
	return 1;
}
