#include <command.h>
#include <gamelib/include/gamelib.h>
// 开始挂机
int main(string arg)
{
	string s = "";
	object me = this_player();
	string type = "";      //类型
	string typeDes = "";  //类型描述
	int time = 0;          //时间
	int yushi = 0;         //需要扣除的玉石
	sscanf(arg,"%s %d %d",type,time,yushi);
	if(type == "xiuchan"){
		typeDes = "修禅";
	}
	else if(type == "dazuo"){
		typeDes = "打坐";
	}
	if(!AUTO_LEARND->is_now_auto_learn(me->query_name()))           //防止重复提交
	{
		int result = BUYD->do_trade(me,yushi,0);
		switch(result){
			case 0:
				s += "你身上的玉石不够！\n";
				break;
			case 1:
				s += "你身上的金钱不够！\n";
				break;
			case 2..3://支付成功
				if(time>=5)
				{
					AUTO_LEARND->add_new_player(type,me,time);
					if(type == "xiuchan"){
						me->set_auto_learn_xiuchan(0);
					}
					else if(type == "dazuo"){
						me->set_auto_learn_dazuo(0);
					}
					string c_log  = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][auto_learn][type:"+type+"][time:"+time+"][1]["+yushi+"][0]\n";
					if(c_log != "")
						Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
					me->command("sleep_for_learn "+time);
					return 1;
				}
				else
					s += "你预定的"+typeDes+"时间为"+time+"分钟，要开始修炼，剩余时间必须在5分钟以上。\n";
				break;
			default:
				s += "系统犯晕了，请和管理员联系。\n";
		}
	}
	else
	{
		s += "你已经在修炼过程中，请不要重复提交请求\n";
	}
	s += "[返回:look]\n";
	write(s);
	return 1;
}
