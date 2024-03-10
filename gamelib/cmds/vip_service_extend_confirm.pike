#include <command.h>
#include <gamelib/include/gamelib.h>
/*
会员续费结果页面
auther: evan
2008.07.16
*/
int main(string arg)
{
	object me = this_player();
	string c_log = "";
	string re = "***会员续费***\n\n";
	int price = (int)arg;//续费价格
	int state = VIPD->get_vip_state(me);
	if(state)//如果是会员
	{
		int trade_result = BUYD->do_trade(me,price*10,0);//交易是否成功
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
				int level = me->query_vip_flag();
				string vip_name = VIPD->get_vip_name(level);
				int endTime = VIPD->give_vip_to(me,level);
				int cost_reb =price*10;
				c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][vip_ex][]["+vip_name+"]["+level+"]["+cost_reb+"][0]\n";
				re += "恭喜，续费成功！\n";
				re += VIPD->get_vip_state_des_withoutlink(me);
				re += "[进入会员欢购场:vip_myzone]\n";
				break;
			default:
				re += "系统犯晕了，请和管理员联系。\n";
				break;
		}
	}
	else//非会员则给出申请提示
	{
		re += VIPD->get_vip_state_des_withoutlinks(me);
		re += "[申请:vip_service_app_detail.pike ]\n\n";
	}
	if(c_log!=""){
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	}
	re += "[返回:vip_service_list.pike]\n";
	re += "[返回游戏:look]\n";
	write(re);
	return 1;
}
