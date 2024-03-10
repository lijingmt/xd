#include <command.h>
#include<wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	object ob = find_player(arg);
	string uid ="";
	sscanf(arg,"%s",uid);
	int result = me->insert_spy_info(uid);
	switch(result){
		case 0:
			s += "你关注的玩家已经达到10个，请删除一些后再来吧。\n";
			break;
		case 1:
			s += "该玩家已经在你的关注里面了，不要重复添加哦。\n";
			break;
		case 2:
			s += "恭喜，你已经把"+ob->query_name_cn()+"添加到关注列表，在好友链接里可以随时购买该玩家的情报。\n";
			break;
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
