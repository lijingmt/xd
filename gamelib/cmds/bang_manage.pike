#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = level,调用者的权限 
int main(string arg)
{
	object me = this_player();
	string s = "";
	int level = (int)arg;
	if(!me->bangid){
		s = "你未加入任何帮派\n";
	}
	else{
		string bang_name = BANGD->query_bang_name(me->bangid);
		s += "<"+bang_name+">:";
		s += BANGD->query_level_cn(me->query_name(),me->bangid)+"\n";
		s += "[帮派通告:bang_change_notice](点击更改)：\n";
		s += BANGD->query_bang_notice(me->bangid)+"\n";
		s += "--------\n";
		s += "[帮派简介:bang_change_desc](点击更改)：\n";
		s += BANGD->query_bang_desc(me->bangid)+"\n";
		s += "--------\n";
		s += "等级称谓";
		if(level == 6)
			s += "(每个不能多于6个字，点击更改)";
		s += "：\n";
		s += BANGD->query_bang_levels(me->bangid,level)+"\n";
		s += "--------\n";
		if(level == 6){
			s += "[转让帮主:bang_change_root]\n";
			s += "[解散帮派:bang_dismiss]\n";
		}
	}
	s += "[返回:my_bang]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
