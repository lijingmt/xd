#include <command.h>
#include <gamelib/include/gamelib.h>
//江湖
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	s += "江湖\n\n";
	s += "[游戏公告:msg_read player new]\n";
	s += "[江湖排行榜:paihang_list account 1]\n";
	s += "[我的好友:my_qqlist]\n";
	s += "[当前玩家:userlist]\n";
	s += "[聊天内容:chatroom_list]\n";
	if(me->can_change_faction())
		s += "[转换阵营:race_change]\n";
	else
		s += "方士为中立职业，可往来仙妖两界，无需转换阵营。\n";
	s += "[返回:look]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
