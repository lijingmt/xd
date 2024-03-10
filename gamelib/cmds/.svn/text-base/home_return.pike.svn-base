#include <command.h>
#include <gamelib/include/gamelib.h>
//玩家传送回家
int main(string arg)
{
	string s = "";
	object me = this_player();
	//如果玩家在某个家园（自己或别人）中，则要清除该玩家在该home中的记录
	if(me->if_in_home())
		HOMED->clear_user(me);
	//开始进入自己的家园
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
		s += "你家的地契出了点问题，房屋已经暂时被官府查封了！\n";
		s += "\n[确定:look]\n";
		write(s);
		return 1;
	}
	return 1;
}
