#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	int level = 0;
	if(!me->bangid){
		s = "你未加入任何帮派\n";
	}
	else{
		string bang_name = BANGD->query_bang_name(me->bangid);
		s += "<"+bang_name+">:";
		s += BANGD->query_level_cn(me->query_name(),me->bangid)+"\n";
		level = BANGD->query_level(me->query_name(),me->bangid);
		if(level != 6){
			s = "你现在已不是帮主\n";
		}
		else{
			s += "只有三级以上的帮员才能接受你的转交，请考虑清楚后，点击帮员完成转交\n";
			s += BANGD->query_for_root(me);
		}
	}
	s += "[返回:bang_manage "+level+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
