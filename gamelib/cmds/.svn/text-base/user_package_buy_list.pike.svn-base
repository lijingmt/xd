#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s="¹ºÂò\n\n";
	if(!arg){
		s += "[¹ºÂò±³°ü:user_package_buy_list beibao]\n";
		s += "[¹ºÂò²Ö¿â:user_package_buy_list cangku]";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else{
		string type = arg;
		if(type=="cangku"){
			s += "[»Æ½ð¹ºÂò:user_package_buy]\n";
		}
		s += BUYD->get_pac_list(type,"user_package_buy_confirm");
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
