#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s="����\n\n";
	if(!arg){
		s += "[���򱳰�:user_package_buy_list beibao]\n";
		s += "[����ֿ�:user_package_buy_list cangku]";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else{
		string type = arg;
		if(type=="cangku"){
			s += "[�ƽ���:user_package_buy]\n";
		}
		s += BUYD->get_pac_list(type,"user_package_buy_confirm");
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
