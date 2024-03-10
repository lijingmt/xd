#include <command.h>
#include <gamelib/include/gamelib.h>
#define TEMPLATE_PATH ROOT "/gamelib/d/home/template/function/"
//ʵ����ʯ�����ܷ���

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
	string c_log = "";//ͳ���õ���־
	sscanf(arg,"%s %d %d",roomName,yushi,money);
	object room;
	if(HOMED->if_can_buy_functionroom(me->query_name())){
		//�ﵽ������������
		s += "����ӵ�еĹ��ܷ��������Ѵﵽ���ޣ���������ӱ�Ĺ��ܷ���\n";
		s += "\n[����:popview]\n";
		write(s);
		return 1;
	}
	mixed err = catch{
		room = (object)(TEMPLATE_PATH + roomName);
	};
	if(!err && room){
		string roomNameCn = room->query_name_cn();
		//�ж��Ƿ��Ƿ��������
		if(HOMED->is_master(homeId)){
			//�жϼ�԰�ȼ������Ƿ�����
			if(HOMED->get_home_level(me->query_name())<room->query_level_limit()){
				//�ȼ�����
				s += "ֻ��"+room->query_level_limit()+"�����ϵļ�԰��������������,���ļ�԰�ȼ�����\n";
				s += "[����:popview]\n";
				write(s);
				return 1;
			}
			//�ж��Ƿ��Ѿ������������
			if(!HOMED->if_have_function_room(roomName)){
				int yushi_t = yushi;
				int money_t = money*100;//�õ��Ĳ�����"��"Ϊ��λ������ʱ��"��"Ϊ��λ.
				int trade_result = BUYD->do_trade(me,yushi_t,money_t);
				switch(trade_result){
					case 0:
						s += "�����ϵ���ʯ������\n";
						break;
					case 1:
						s += "�����ϵĽ�Ǯ������\n";
						break;
					case 2..3:
						int addResult = HOMED->add_function_room(roomName);//��ӹ��ܷ���
						if(addResult){ //��ӳɹ�
							int cost_reb = yushi_t;
							c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_functionroom]["+ roomNameCn +"][1][1]["+cost_reb+"][0]\n";
							s += "���Ѿ����Լ��ļ�԰�������"+ roomNameCn +"\n";
							if(roomName == "feitianxiaowu")
							{
								s += "�����淿������һ��'�������'��ʹ��������ָ�������԰������ķ��䣬��������������ӻ����˴����򵽡�\n";
							}
						}
						else//���ʧ��
							s +="ϵͳ�е����ˣ���ķ��䲢û����ӳɹ����������ʣ�����ͷ���ϵ\n";
						break;
					default:
						s += "ϵͳ�����ˣ���͹���Ա��ϵ��\n";
				}
				s += "[�������:home_functionroom_buy_list]\n";
			}
			else{
				s = "��԰���Ѿ���������䣬�벻Ҫ�ظ����\n";
			}
		}
		else
		{
			s = "�㲻�Ǽ�԰�����ˣ������㲻����ȷ��λ��\n";
		}
	}
	else
	{
		s = "��������Ƚ�æ����ҵ���չ��Ҫ��һ��ʱ��\n";
	}
	if(c_log != "")                                                                           
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
