#include <globals.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "[���Ź�:home_buy_dog_detail vice_npc/huoyunquan 80]\n";
	s += "[�����:buy_items home_door all]\n";
	s += "[����ʳƷ:buy_items home_feed goudou]\n";
	s += "[�ػ굤(����ר��):buy_items home_fuhuo all]\n";
	s += "[�������:buy_items home_function all]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
