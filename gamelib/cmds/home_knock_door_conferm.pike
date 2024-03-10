#include <command.h>
#include <gamelib/include/gamelib.h>

//敲门调用指令

int main(string arg)
{
	object me = this_player();
	string s = "";
	object room;
	/*
	object room = environment(me);
	string master_name = room->masterId;
	object master = find_player(master_name);
	*/
	string my_name = me->query_name();
	if(HOMED->if_have_home(my_name)){
		room = HOMED->query_room_by_masterId(my_name,"main");
	}
	string msg = "";
	string kd_name = "";//敲门玩家的id
	string result = "";
	sscanf(arg,"%s %s",kd_name,result);
	object kn_user = find_player(kd_name);
	if(!kn_user){
		msg += "该玩家已经离开\n";
		msg += "[返回游戏:look]\n";
		write(msg);
		return 1;
	}
	if(result=="yes"){
		s += me->query_name_cn()+"打开大门，热烈的欢迎你的到来\n";
		s += "\n[进入:home_visit "+me->query_name()+"]\n";
		//s += "[告辞离开:look]\n";
		kn_user->home_rights[1]=my_name;
		msg += "您开心的给"+kn_user->query_name_cn()+"打开了大门，热烈的欢迎他的到来\n";
	}
	else if(result=="no"){
		s += me->query_name_cn()+"看起来好像没空招待你，改天再来吧～\n";
		//s += "[继续敲门:home_knock_door "+me->query_name()+"]\n";
		//s += "[离开:look]\n";
		msg += "您拒绝了"+kn_user->query_name_cn()+"的请求\n";
	}
	//s += "[离开这里:home_leave "+ room->query_slotName()+" "+room->query_flatName() +"]\n\n";
	msg += "[返回:look]\n";
	write(msg);
	//me->command("look");
	tell_object(kn_user,s);
	return 1;
}
