#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(me->query_raceId()=="human")
		s += CHATROOMD->query_chatroom_list();
	else if(me->query_raceId()=="monst")
		s += CHATROOM2D->query_chatroom_list();
	s += "[屏蔽列表:chatroom_blocklist]\n";
	s += "[返回游戏:look]\n";
	s += "[imgurl picture:http://tx.com.cn/img/tx/gogo/logo.png?t=$(System.Time()->usec_full)]\n";
	write(s);
	return 1;
}

