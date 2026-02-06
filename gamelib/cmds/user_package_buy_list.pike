#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s="购买\n\n";
	if(!arg){
		s += "[购买背包:user_package_buy_list beibao]\n";
		s += "[购买仓库:user_package_buy_list cangku]";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else{
		string type = arg;
		if(type=="cangku"){
			s += "[黄金购买:user_package_buy]\n";
		}
		s += BUYD->get_pac_list(type,"user_package_buy_confirm");
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
