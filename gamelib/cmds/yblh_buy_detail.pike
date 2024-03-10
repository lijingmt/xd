#include <command.h>                                                                                                         
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string s = "";
	string name = "";
	int yushi = 0;
	s += BUYD->item_view("baoxiang/yuebinglihe",20,0);
	s += "\n";
	s += "\n[È·¶¨¹ºÂò:yblh_buy_confirm baoxiang/yuebinglihe 20]";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
