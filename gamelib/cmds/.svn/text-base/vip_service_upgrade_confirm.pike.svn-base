#include <command.h>
#include <gamelib/include/gamelib.h>
/*
   会员升级结果页面
auther: evan
2008.07.18
 */
int main(string arg)
{
	object me = this_player();
	string re = "***会员升级***\n\n";
	int level = 0;
	int cost = 0;
	string c_log = "";
	sscanf(arg,"%d %d",level,cost);
	int trade_result = BUYD->do_trade(me,cost*10,0);//交易是否成功
	switch(trade_result){
		case 0:
			re += "你身上的玉石不够！\n";
			break;
		case 1:
			re += "你身上的金钱不够！\n";
			break;
			/*case 2:
			//re += "你身上的空间不够！\n";
			break;*/
		case 2..3:
			me->set_vip_flag(level);
			int endTime = me->query_vip_end_time();
			string vip_name = VIPD->get_vip_name(level);
			string endTimeToShow = TIMESD->get_user_year_month_day(endTime);
			int cost_reb =cost*10;
			c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][vip_up][ ]["+vip_name+"]["+level+"]["+cost_reb+"][0]\n";
			re += "恭喜，你已经成为"+vip_name+",会员资格将在"+endTimeToShow+"过期。\n\n";
			re += "[进入会员欢购场:vip_myzone]\n";
			break;
		default:
			re += "系统犯晕了，请和管理员联系。\n";
			break;
	}
	if(c_log!=""){
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	}
	re += "[返回:yushi_myzone.pike]\n";
	re += "[返回游戏:look]\n";
	write(re);
	return 1;
}
