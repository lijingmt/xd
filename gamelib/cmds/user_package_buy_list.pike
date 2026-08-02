#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	string s="§g扩充容量§r\n\n";
	if(!arg){
		s += "[扩充背包:user_package_buy_list beibao]\n";
		s += "[扩充当前角色仓库:user_package_buy_list cangku]";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else{
		string type = arg;
		if(type=="cangku"){
			s += "[金币扩充10格:user_package_buy]\n";
		}
		s += BUYD->get_pac_list(type,"user_package_buy_confirm");
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
