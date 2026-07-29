#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	s += RACECHATD->query_chatroom_list(me->query_raceId());
	s += "[屏蔽列表:chatroom_blocklist]\n";
	s += "[返回游戏:look]\n";
	s += "[imgurl picture:http://tx.com.cn/img/tx/gogo/logo.png?t=$(System.Time()->usec_full)]\n";
	write(s);
	return 1;
}
