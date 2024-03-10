#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name 
//      name 为目标玩家id
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!me->bangid){
		s = "你未加入任何帮派\n";
	}
	else{
		object target = find_player(arg);
		if(target){
			if(arg==me->query_name()){
				s+="你不能对自己执行该操作，请返回。\n";
			}
			else{
				string name_cn = target->query_name_cn();	
				s += name_cn+"\n";
				s += "[发消息:tell "+arg+"]\n";
				s += "[加为好友:qqlist "+arg+"]\n";
			}
		}
		else
			s += "对方已经离线\n";
	}
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "[返回:my_bang]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
