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
		write("购买参数无效。\n[返回:popview]\n[返回游戏:look]\n");
		return 1;
	}
	mapping(string:mixed) offer=HOMED->query_function_room_offer(roomName);
	if(!sizeof(offer)){
		write("该功能房不在服务端目录中。\n"+
			"[返回:popview]\n[返回游戏:look]\n");
		return 1;
	}
	mapping(string:mixed) result=HOMED->purchase_function_room(me,roomName);
	string s=(string)result["message"]+"\n";
	if((int)result["ok"]){
		string roomNameCn=(string)(offer["name_cn"] || roomName);
		s="你已经在自己的家园中添加了"+roomNameCn+"\n";
		if(roomName=="feitianxiaowu")
			s+="我们随房赠送了一张传送神符。\n";
		string c_log="["+MUD_TIMESD->get_mysql_timedesc()+"]-["+
			GAME_NAME_S+"]["+me->query_name()+"][home_functionroom]["+
			roomNameCn+"][1][1]["+(string)((int)result["yushi"])+
			"][0]\n";
		mixed log_err=catch{
			Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+
				"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
		};
		if(log_err)
			werror("[HOME_AUDIT] append failed: %s\n",describe_error(log_err));
	}
	s+="[继续添加:home_functionroom_buy_list]\n";
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
