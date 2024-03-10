#include <command.h>
#include <gamelib/include/gamelib.h>
#define ITEM_PATH ROOT "/gamelib/clone/item/other/"

int main(string arg)
{
	object me = this_player();
	string s = "";
	string c_log = "";//统计使用的日志
	string slotName = "";
	string flatName = "";
	string homeName = "";
	sscanf(arg,"%s %s %s",slotName,flatName,homeName);

	int yushi = HOMED->query_yushi_by_slot(slotName);//所需玉石(碎玉为单位)
	int money = HOMED->query_money_by_slot(slotName);//所需金钱(金为单位)

	if(HOMED->if_have_home(me->query_name()))//每个玩家只能购买一处房产
	{
		s += "你已经有一处房产了，不能购买更多\n";
	}
	else{


		int trade_result = BUYD->do_trade(me,yushi,money*100);//付款是否成功
		switch(trade_result){
			case 0:
				s += "你身上的玉石不够！\n";
				break;
			case 1:
				s += "你身上的金钱不够！\n";
				break;
				/*case 2:
				//re += "你身上的空间不够！\n";
				break;*/
			case 2..3:
				HOMED->build_new_home(homeName,flatName,slotName);
				int cost_reb = yushi;
				c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home]["+slotName+"]["+flatName+"][1]["+cost_reb+"][0]\n";
				s += "恭喜，你已经成功购买了这里的地产，现在可以进入自己的家中体验最新的功能了\n";
				s += "[进入我的家:home_view "+ homeName +"]\n";
				break;
			default:
				s += "系统犯晕了，请和管理员联系。\n";
		}
		if(c_log != "")                                                                           
			Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
