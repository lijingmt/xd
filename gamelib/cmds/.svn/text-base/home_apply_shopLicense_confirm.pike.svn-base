#include <command.h>
#include <gamelib/include/gamelib.h>
#define TEMPLATE_PATH ROOT "/gamelib/d/home/template/function/"
//实现玉石购买功能房间

int main(string arg)
{
	object me = this_player();
	//object env = environment(me);
	string masterId = me->query_name();
	//string homeId = env->query_homeId();
	string roomName = "";
	string roomNameCn = "私家小店";
	int yushi = 0;
	//int money = 0;
	string s ="";
	string c_log = "";//统计用的日志
	sscanf(arg,"%s %d",roomName,yushi);
	object room;
	//string roomNameCn = room->query_name_cn();
	//判断该玩家是否有家园
	if(HOMED->if_have_home(masterId)){
		//判断是否有许可
		if(!HOMED->if_have_shopLicense(masterId)){
			int yushi_t = yushi;
			//int money_t = money*100;//得到的参数以"金"为单位，处理时以"银"为单位.
			int trade_result = BUYD->do_trade(me,yushi_t,0);
			switch(trade_result){
				case 0:
					s += "你身上的玉石不够！\n";
					break;
				case 1:
					s += "你身上的金钱不够！\n";
					break;
				case 2..3:
					HOMED->add_shop_license(masterId,roomName);//添加店铺
					int cost_reb = yushi_t;
					c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ masterId +"][home_shop]["+ roomNameCn +"][1][1]["+cost_reb+"][0]\n";
					s += "你得到了店铺许可,你可以在"+ roomNameCn +"里摆放你想要出售的物品\n";
					break;
				default:
					s += "系统犯晕了，请和管理员联系。\n";
			}
		}
		else{
			s = "你已经有了店铺许可,请不要重复申请\n";
		}
	}
	else
	{
		s = "你还没有地产,不能开店\n";
	}
	if(c_log != "")                                                                           
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	s += "\n\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
