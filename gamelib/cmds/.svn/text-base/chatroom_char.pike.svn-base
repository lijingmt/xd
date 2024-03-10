#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s+="你要观察哪个用户的信息？\n";
		s+="请返回。\n";
	}
	else{
		if(arg==me->query_name()){
			s+="你不能对自己执行该操作，请返回。\n";
			s+="[返回:chatroom_entry "+me->query_chatid()+"]\n";
			s+="[返回游戏:look]\n";
			write(s);
			return 1;
		}
		object who = find_player(arg);
		if(who){
			s += who->query_name_cn()+"\n";	
			s += "[发消息:tell "+who->query_name()+"]\n";
			s += "[加为好友:qqlist "+who->query_name()+"]\n";
			if(me["/plus/chatblock"]&&sizeof(me["/plus/chatblock"])){
				int flag = 1;
				foreach(me["/plus/chatblock"],string uid){
					if(uid&&uid==who->query_name()){
						//该观察者屏蔽聊表中有该发言者的ｉｄ
						s += "[解除此人屏蔽:chatroom_disblock "+who->query_name()+"]\n";
						flag  = 0;
						break;
					}
				}
				if(flag){
					//该发言者没有在观察者的屏蔽聊表中，提供屏蔽接口
					s += "[屏蔽此人:chatroom_block "+who->query_name()+"]\n";
				}
			}
			else//该观察者还没有屏蔽过任何人，可以提供屏蔽接口
				s += "[屏蔽此人:chatroom_block "+who->query_name()+"]\n";
		}
		else{
			s += "该用户已经离开，请返回。\n";	
		}
	}
	s+="[返回:chatroom_entry "+me->query_chatid()+"]\n";
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
