#include <globals.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "[看门狗:home_buy_dog_detail vice_npc/huoyunquan 80]\n";
	s += "[买个门:buy_items home_door all]\n";
	s += "[宠物食品:buy_items home_feed goudou]\n";
	s += "[回魂丹(宠物专用):buy_items home_fuhuo all]\n";
	s += "[传送神符:buy_items home_function all]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
