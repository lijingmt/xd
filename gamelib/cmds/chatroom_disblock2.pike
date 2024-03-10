#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg)
		s+="你要解除对哪个玩家的屏蔽？\n";
	else{
		if(me["/plus/chatblock"]&&sizeof(me["/plus/chatblock"])){
			int flag = 1;
			foreach(me["/plus/chatblock"],string uid){
				if(uid&&uid==arg){
					me["/plus/chatblock"] -= ({arg});
					flag  = 0;
					break;
				}
			}
			if(flag)
				s += "该用户并未被你屏蔽过发言内容，请返回重新选择。\n";
			else
				s += "你已经解除了对该玩家的屏蔽，请返回。\n";	
		}
		else//该观察者还没有屏蔽过任何人，可以提供屏蔽接口
			s += "你还没有屏蔽过任何人，请返回重新选择并确认无误。\n";
	}
	s+="[返回:chatroom_blocklist]\n";
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
