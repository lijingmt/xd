#include <command.h>
#include <gamelib/include/gamelib.h>
/*
   ��Ա�������ҳ��
auther: evan
2008.07.18
 */
int main(string arg)
{
	object me = this_player();
	string re = "***��Ա����***\n\n";
	int level = 0;
	int cost = 0;
	string c_log = "";
	sscanf(arg,"%d %d",level,cost);
	int trade_result = BUYD->do_trade(me,cost*10,0);//�����Ƿ�ɹ�
	switch(trade_result){
		case 0:
			re += "�����ϵ���ʯ������\n";
			break;
		case 1:
			re += "�����ϵĽ�Ǯ������\n";
			break;
			/*case 2:
			//re += "�����ϵĿռ䲻����\n";
			break;*/
		case 2..3:
			me->set_vip_flag(level);
			int endTime = me->query_vip_end_time();
			string vip_name = VIPD->get_vip_name(level);
			string endTimeToShow = TIMESD->get_user_year_month_day(endTime);
			int cost_reb =cost*10;
			c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][vip_up][ ]["+vip_name+"]["+level+"]["+cost_reb+"][0]\n";
			re += "��ϲ�����Ѿ���Ϊ"+vip_name+",��Ա�ʸ���"+endTimeToShow+"���ڡ�\n\n";
			re += "[�����Ա������:vip_myzone]\n";
			break;
		default:
			re += "ϵͳ�����ˣ���͹���Ա��ϵ��\n";
			break;
	}
	if(c_log!=""){
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	}
	re += "[����:yushi_myzone.pike]\n";
	re += "[������Ϸ:look]\n";
	write(re);
	return 1;
}
