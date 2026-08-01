#include <command.h>
#include <gamelib/include/gamelib.h>
#ifndef ITEM_PATH
#define ITEM_PATH ROOT "/gamelib/clone/item/other/"
#endif

int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	string c_log = "";//统计使用的日志
	string slotName = "";
	string flatName = "";
	string homeName = "";
	mapping(string:mixed) result;
	sscanf(arg,"%s %s %s",slotName,flatName,homeName);
	result = HOMED->purchase_home(me,homeName,flatName,slotName);
	if((int)result["ok"]){
		int cost_reb = (int)result["yushi"];
		c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+
			"["+GAME_NAME_S+"]["+me->query_name()+"][home]["+
			slotName+"]["+flatName+"][1]["+cost_reb+"][0]\n";
		s += "恭喜，你已经成功购买了这里的地产，现在可以进入自己的家中体验最新的功能了\n";
		s += "[进入我的家:home_view "+(string)result["home_ref"]+"]\n";
	}
	else{
		s += (string)result["message"]+"\n";
	}
	if(c_log!="")
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+
			"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
