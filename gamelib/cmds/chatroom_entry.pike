#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	if(!arg || arg == "0"){
		s+="你要进入哪个聊天频道？\n";
		s+="请返回选择聊天频道。\n";
	}
	else{
		me->set_chatid(arg);
		//if(me->query_level()>=6) //为了屏蔽枪手而做的修改
		//s += "[刷新:chatroom_chat flush]\n[chatroom_chat ...]\n";
		s += "[刷新:chatroom_chat flush]\n[chatroom_chat ...]\n";
		s += RACECHATD->query_chat_msg(
			me->query_raceId(),me->query_chatid(),me->query_name());
	}
	s+="[返回:chatroom_list]\n";
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
