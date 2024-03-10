#include <command.h>
#include <gamelib/include/gamelib.h>
#define INFANCY_PATH ROOT "/gamelib/clone/item/home/infancy/"
//ʵ����ʯ����infancy

int main(string arg)
{
	object me = this_player();
	string infancyName = "";
	int yushi = 0;
	int money = 0;
	string numTmp = "";
	int num = 0;
	string s ="";
	string c_log = "";//ͳ���õ���־
	sscanf(arg,"%s %d %d %s",infancyName,yushi,money,numTmp);
	sscanf(numTmp,"no=%d",num);
	if(num<1 || num>20)
		s += "�������󣡹������������1��20֮��\n";
	else{
		object infancy;
		mixed err = catch{
			//infancy = (object)(INFANCY_PATH + infancyName);
			infancy = clone(INFANCY_PATH + infancyName);
			infancy->set_amount(num);
		};
		if(!err && infancy){
			int yushi_t = yushi*num;
			int money_t = money*num*100;//�õ��Ĳ�����"��"Ϊ��λ������ʱ��"��"Ϊ��λ.
			string infancyUnit = infancy->query_unit();
			string infancyNameCn = infancy->query_name_cn();
			int trade_result = BUYD->do_trade(me,yushi_t,money_t);
			switch(trade_result){
				case 0:
					s += "�����ϵ���ʯ������\n";
					break;
				case 1:
					s += "�����ϵĽ�Ǯ������\n";
					break;
					/*case 2:
					//re += "�����ϵĿռ䲻����\n";
					break;*/
				case 2..3:
					infancy->move_player(me->query_name());
					int cost_reb = yushi_t;
					c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_infancy]["+ infancyNameCn +"]["+num+"][1]["+cost_reb+"][0]\n";
					s += "������"+ num + infancyUnit + infancyNameCn +"\n";
					break;
				default:
					s += "ϵͳ�����ˣ���͹���Ա��ϵ��\n";
			}
			s += "[��������:home_shop_item_list plant]\n";
		}
		else
		{
			s += "��Ҫ����Ķ����Ѿ������ˣ���һ��ʱ��������.\n";
		}
		if(c_log != "")                                                                           
			Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	}
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
