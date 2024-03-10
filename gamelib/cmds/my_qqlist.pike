#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	this_player()->write_view(WAP_VIEWD["/my_qqlist"]);
	return 1;
	/*
	string s = "";
	object me = this_player();
	//s += me->drain_catch_tell(0,3)+"\n";
	s += "【好友系统】\n";
	s += "[未分组:qqlist]\n";
	s += me->view_qqlist_groups()+"\n";
	s += "[屏蔽列表:blacklist]\n";
	s += "[聊天记录:qqlist_history]\n";
	s += "[信箱:mailbox]\n";
	s += "[好友管理:qqlist_admin_groups]\n";
	s += "[返回游戏:look]\n";
	return 1;
	*/
}
