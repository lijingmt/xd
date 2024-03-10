#include <command.h>
#include <gamelib/include/gamelib.h>
#define INFANCY_PATH ROOT "/gamelib/clone/item/home/infancy/"
//实现玉石购买infancy

int main(string arg)
{
	object me = this_player();
	string infancyName = "";
	int yushi = 0;
	int money = 0;
	string numTmp = "";
	int num = 0;
	string s ="";
	string c_log = "";//统计用的日志
	sscanf(arg,"%s %d %d %s",infancyName,yushi,money,numTmp);
	sscanf(numTmp,"no=%d",num);
	if(num<1 || num>20)
		s += "输入有误！购买个数必须在1到20之间\n";
	else{
		object infancy;
		mixed err = catch{
			//infancy = (object)(INFANCY_PATH + infancyName);
			infancy = clone(INFANCY_PATH + infancyName);
			infancy->set_amount(num);
		};
		if(!err && infancy){
			int yushi_t = yushi*num;
			int money_t = money*num*100;//得到的参数以"金"为单位，处理时以"银"为单位.
			string infancyUnit = infancy->query_unit();
			string infancyNameCn = infancy->query_name_cn();
			int trade_result = BUYD->do_trade(me,yushi_t,money_t);
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
					infancy->move_player(me->query_name());
					int cost_reb = yushi_t;
					c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_infancy]["+ infancyNameCn +"]["+num+"][1]["+cost_reb+"][0]\n";
					s += "你获得了"+ num + infancyUnit + infancyNameCn +"\n";
					break;
				default:
					s += "系统犯晕了，请和管理员联系。\n";
			}
			s += "[继续购买:home_shop_item_list plant]\n";
		}
		else
		{
			s += "你要购买的东西已经卖光了，过一段时间再来吧.\n";
		}
		if(c_log != "")                                                                           
			Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
