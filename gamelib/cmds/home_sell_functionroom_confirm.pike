#include <command.h>
#include <gamelib/include/gamelib.h>
#define FUNCTIONROOM_PATH ROOT "/gamelib/d/home/template/function/"
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	int yushi = 0;
	int money = 0;
	string f_room_name = "";
	if(!arg || sscanf(arg,"%s %d %d",f_room_name,yushi,money)!=3){
		write("变卖参数无效。\n[返回游戏:look]\n");
		return 1;
	}
	mapping(string:mixed) offer=HOMED->query_function_room_offer(
		f_room_name);
	if(!sizeof(offer)){
		write("该功能房不在服务端目录中。\n[返回游戏:look]\n");
		return 1;
	}
	yushi=(int)offer["sell_yushi"];
	money=(int)offer["sell_money"];
	if(!HOMED->if_have_home(me->query_name()))
	{
		s += "你还没有地产，空手套白狼在这里可行不通\n";
	}
	else
	{
		int rt = HOMED->sell_function_room(f_room_name,yushi,money);
		if(rt){
			s += "你得到了:\n";
			s += YUSHID->get_yushi_for_desc(yushi);
			if(money){
				s += "和"+money+"金\n";
			}
		}
		else{
			s += "变卖失败～\n";
		}
	}
	s += "\n[返回:home_functionroom_remind home_base]\n";
	s += "[返回游戏:look]\n"; 
	write(s);
	return 1;
}
