#include <command.h>
#include <gamelib/include/gamelib.h>
//该指令列出获奖者的奖励名单
int main(string arg)
{
	string s = "领奖处：\n";
	object me=this_player();
	s += GIFTD->query_gift_info(me->query_name());
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
