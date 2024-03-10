#include <command.h>
#include<wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	object ob = find_player(arg);
	string uid =arg;
	int result = me->delete_spy_info(uid);
	switch(result){
		case 0:
			s += "删除关注信息失败，请重试。\n";
			break;
		case 1:
			s += "该玩家不在你的关注列表中。\n";
			break;
		case 2:
			s += "删除关注信息成功，请返回。\n";
			break;
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
