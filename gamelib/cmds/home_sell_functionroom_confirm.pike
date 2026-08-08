#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me=this_player();
	string roomName="";
	int ignored_yushi=0;
	int ignored_money=0;
	if(!arg || sscanf(arg,"%s %d %d",roomName,ignored_yushi,
	   ignored_money)!=3){
		write("变卖参数无效。\n[返回游戏:look]\n");
		return 1;
	}
	mapping(string:mixed) offer=HOMED->query_function_room_offer(roomName);
	if(!sizeof(offer)){
		write("该功能房不在服务端目录中。\n[返回游戏:look]\n");
		return 1;
	}
	mapping(string:mixed) result=HOMED->sell_function_room_transaction(
		me,roomName);
	string s=(string)result["message"]+"\n";
	if((int)result["ok"]){
		s="你得到了:\n"+
			YUSHID->get_yushi_for_desc((int)result["yushi"]);
		if((int)result["money"]>0)
			s+="和"+(string)((int)result["money"]/100)+"金\n";
	}
	s+="\n[返回:home_functionroom_remind home_base]\n";
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
