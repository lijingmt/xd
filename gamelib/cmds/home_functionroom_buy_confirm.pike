#include <command.h>
#include <gamelib/include/gamelib.h>
#define TEMPLATE_PATH ROOT "/gamelib/d/home/template/function/"
//实现玉石购买功能房间

int main(string arg)
{
	object me = this_player();
	object env = environment(me);
	string homeId = env->query_homeId();
	string roomName = "";
	string roomNameCn = "";
	int yushi = 0;
	int money = 0;
	string s ="";
	string c_log = "";//统计用的日志
	sscanf(arg,"%s %d %d",roomName,yushi,money);
	object room;
	if(HOMED->if_can_buy_functionroom(me->query_name())){
		//达到购买数量上限
		s += "您所拥有的功能房间数量已达到上限，不能再添加别的功能房间\n";
		s += "\n[返回:popview]\n";
		write(s);
		return 1;
	}
	mixed err = catch{
		room = (object)(TEMPLATE_PATH + roomName);
	};
	if(!err && room){
		string roomNameCn = room->query_name_cn();
		//判断是否是房间的主人
		if(HOMED->is_master(homeId)){
			//判断家园等级条件是否满足
			if(HOMED->get_home_level(me->query_name())<room->query_level_limit()){
				//等级不够
				s += "只有"+room->query_level_limit()+"级以上的家园才能添加这个房间,您的家园等级不够\n";
				s += "[返回:popview]\n";
				write(s);
				return 1;
			}
			//判断是否已经有这个房间了
			if(!HOMED->if_have_function_room(roomName)){
				int yushi_t = yushi;
				int money_t = money*100;//得到的参数以"金"为单位，处理时以"银"为单位.
				int trade_result = BUYD->do_trade(me,yushi_t,money_t);
				switch(trade_result){
					case 0:
						s += "你身上的玉石不够！\n";
						break;
					case 1:
						s += "你身上的金钱不够！\n";
						break;
					case 2..3:
						int addResult = HOMED->add_function_room(roomName);//添加功能房间
						if(addResult){ //添加成功
							int cost_reb = yushi_t;
							c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_functionroom]["+ roomNameCn +"][1][1]["+cost_reb+"][0]\n";
							s += "你已经在自己的家园中添加了"+ roomNameCn +"\n";
							if(roomName == "feitianxiaowu")
							{
								s += "我们随房赠送了一张'传送神符'，使用它可以指定和你家园相关联的房间，该神符还可以在杂货商人处购买到。\n";
							}
						}
						else//添加失败
							s +="系统有点累了，你的房间并没有添加成功，如有疑问，请与客服联系\n";
						break;
					default:
						s += "系统犯晕了，请和管理员联系。\n";
				}
				s += "[继续添加:home_functionroom_buy_list]\n";
			}
			else{
				s = "家园中已经有这个房间，请不要重复添加\n";
			}
		}
		else
		{
			s = "你不是家园的主人，或者你不在正确的位置\n";
		}
	}
	else
	{
		s = "工匠最近比较忙，你家的扩展需要等一段时间\n";
	}
	if(c_log != "")                                                                           
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
