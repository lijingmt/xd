#include <command.h>
#include <gamelib/include/gamelib.h>

//敲门调用指令

int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	object room = environment(me);
	string master_name = room->masterId;
	object|zero master = find_player(master_name);
	if(master && !LOGICALZONED->can_user_action("home",
	   me->query_name(),master_name))
		master = 0;
	string msg = "";
	if(!arg){
		if(!master){
			s += "主人并不在线，改天再来吧。\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		msg += me->query_name_cn()+"想要拜访您的家\n[同意:home_knock_door_conferm "+me->query_name()+" yes] [拒绝:home_knock_door_conferm "+me->query_name()+" no]\n";
		tell_object(master,msg);
		s += "信息已发出，请耐心等待房主的回应\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	write(s);
	return 1;
}
