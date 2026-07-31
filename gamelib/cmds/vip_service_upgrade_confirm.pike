#include <command.h>
#include <gamelib/include/gamelib.h>
/*
   会员升级结果页面
auther: evan
2008.07.18
 */
int main(string|zero arg)
{
	object me = this_player();
	string re = "***会员升级***\n\n";
	int level = 0;
	int cost = 0;
	string c_log = "";
	sscanf(arg,"%d",level);
	int state = VIPD->get_vip_state(me);
	int old_level = me->query_vip_flag();
	mapping vip_cost_map = VIPD->get_vip_cost_map();
	if(!state || old_level<1 || old_level>=VIP_MAX_LEVEL ||
	   level<=old_level || level>VIP_MAX_LEVEL ||
	   !VIPD->get_vip_name(level)){
		re += "会员升级目标无效，本次没有扣除玉石。\n";
		re += "[返回会员升级:vip_service_upgrade_list]\n";
		write(re);
		return 1;
	}
	cost = (int)vip_cost_map[level]-(int)vip_cost_map[old_level];
	if(state==2 || state==3)
		cost = cost*6/10;
	if(cost<=0){
		re += "会员升级价格无效，本次没有扣除玉石。\n";
		write(re);
		return 1;
	}
	int trade_result = BUYD->do_trade(me,cost*10,0);//交易是否成功
	switch(trade_result){
		case 0:
			re += "你身上的玉石不够！\n";
			re += "[捐赠获取仙玉:add_szx_fee]\n";
			re += "[返回会员升级:vip_service_upgrade_list]\n";
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
			re += "你的等级上限已提高到"+
				VIPD->query_vip_level_limit(level)+"级。\n";
			re += "[进入会员欢购场:vip_myzone]\n";
			break;
		default:
			re += "系统犯晕了，请和管理员联系。\n";
			break;
	}
	if(c_log!=""){
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	}
	re += "[返回会员服务:vip_service_list]\n";
	re += "[返回游戏:look]\n";
	write(re);
	return 1;
}
