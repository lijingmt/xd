#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg)
		s+="你要屏蔽哪个玩家？\n";
	else{
		if(me["/plus/chatblock"]&&sizeof(me["/plus/chatblock"])){
			int belocked = 0;
			foreach(me["/plus/chatblock"],string uid){
				if(uid&&uid==arg){
					belocked  = 1;
					break;
				}
			}
			if(belocked)
				s += "你已经屏蔽过了该玩家，不用重复屏蔽请返回。\n";	
			else{
				me["/plus/chatblock"]+=({arg});
				s += "你已经过滤掉了该玩家在聊天频道的发言内容，请返回。\n";	
			}
		}
		else{
			me["/plus/chatblock"]=({arg});
			s += "你已经过滤掉了该玩家在聊天频道的发言内容，请返回。\n";	
		}
	}
	s+="[返回:chatroom_entry "+me->query_chatid()+"]\n";
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
