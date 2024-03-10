#include <command.h>
#include <gamelib/include/gamelib.h>
#define ITEM_PATH ROOT "/gamelib/clone/item/other/"

int main(string arg)
{
	object me = this_player();
	string s = "";
	string c_log = "";//ͳ��ʹ�õ���־
	string slotName = "";
	string flatName = "";
	string homeName = "";
	sscanf(arg,"%s %s %s",slotName,flatName,homeName);

	int yushi = HOMED->query_yushi_by_slot(slotName);//������ʯ(����Ϊ��λ)
	int money = HOMED->query_money_by_slot(slotName);//�����Ǯ(��Ϊ��λ)

	if(HOMED->if_have_home(me->query_name()))//ÿ�����ֻ�ܹ���һ������
	{
		s += "���Ѿ���һ�������ˣ����ܹ������\n";
	}
	else{


		int trade_result = BUYD->do_trade(me,yushi,money*100);//�����Ƿ�ɹ�
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
				HOMED->build_new_home(homeName,flatName,slotName);
				int cost_reb = yushi;
				c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home]["+slotName+"]["+flatName+"][1]["+cost_reb+"][0]\n";
				s += "��ϲ�����Ѿ��ɹ�����������ĵز������ڿ��Խ����Լ��ļ����������µĹ�����\n";
				s += "[�����ҵļ�:home_view "+ homeName +"]\n";
				break;
			default:
				s += "ϵͳ�����ˣ���͹���Ա��ϵ��\n";
		}
		if(c_log != "")                                                                           
			Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	}
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
