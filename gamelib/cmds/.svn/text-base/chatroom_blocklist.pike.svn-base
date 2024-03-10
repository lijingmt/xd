#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(me["/plus/chatblock"]&&sizeof(me["/plus/chatblock"])){
		foreach(me["/plus/chatblock"],string uid){
			if(uid&&sizeof(uid)){
				object who = find_player(uid);
				if(who){
					s += who->query_name_cn()+"\n";
					s += "[解除此人屏蔽:chatroom_disblock2 "+uid+"]\n";
				}
				else{
					s += "被屏蔽者未在线\n";
					s += "[解除此人屏蔽:chatroom_disblock2 "+uid+"]\n";
				}
			}
		}
	}
	else
		s += "暂无屏蔽玩家。\n";	
	s+="[返回:chatroom_list]\n";
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
