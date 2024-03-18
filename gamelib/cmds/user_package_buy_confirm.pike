#include <command.h>
#include <gamelib/include/gamelib.h>
#define BUY_MAX_COUNT 50
int main(string arg)
{
	object me = this_player();
	string s="";
	string tmp_s = "";
	string s_log = "";
	string type = "";//���ͣ�������ֿ�
	int pac_size = 0;//Ҫ����Ĵ�С
	int need_yushi = 0;//����Ҫ����ʯ
	int flag = 0;//�����־��0���鿴  1��ȷ������  2:��������
	sscanf(arg,"%s %d %d %d",type,pac_size,need_yushi,flag);
	if(type=="beibao") tmp_s += "����";
	if(type=="cangku") tmp_s += "�ֿ�";
	if(flag==0){
		s += "��������"+YUSHID->get_yushi_for_desc(need_yushi)+"����1��"+pac_size+"���"+tmp_s+"\n\n";
		s += "[ȷ�Ϲ���:user_package_buy_confirm "+type+" "+pac_size+" "+need_yushi+" 1]\n";
		s += "[�ٿ���:user_package_buy_confirm "+type+" "+pac_size+" "+need_yushi+" 2]\n";
	}
	else if(flag==2){
		s += "�������Ǻ���������~\n";
	}
	else if(flag==1){
		if(!me->package_expand[type]){
			me->package_expand[type] = ([]);
		}
		if(BUYD->query_cangku_num(me,type)>=BUY_MAX_COUNT){
			s += "ÿ��������ֻ�ܹ���"+BUY_MAX_COUNT+"����������������Ѿ��ﵽ����.\n";
			if(pac_size>5){
				s += "������ѡ�������滻��ʽ���й����µ�"+tmp_s+"��\n";
				s += "["+tmp_s+"�滻:user_package_replace_list "+type+" "+pac_size+"]\n";
			}
			s += "[����:user_package_buy_list]\n";
			s += "[������Ϸ:look]\n";
			write(s);
			return 1;
		}
		int buy_result = BUYD->do_trade(me,need_yushi,0);
		switch(buy_result){
			case 0:
				s += "�����ϵ���ʯ������\n";
				break;
			case 1:
				s += "�����ϵĽ�Ǯ������\n";
				break;
			case 2..3:
				if(!me->package_expand[type][pac_size]){
					me->package_expand[type][pac_size]=1;
				}
				else{
					me->package_expand[type][pac_size]+=1;
				}
				string name_cn = pac_size+"��"+tmp_s;
				s_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"]["+type+"]["+pac_size+type+"]["+name_cn+"][1]["+need_yushi+"][0]\n";
				Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",s_log);
				s += "��ϲ���ɹ�������"+pac_size+"��"+tmp_s+"\n\n";
				break;
			default:
				s += "ϵͳ�����ˣ���͹���Ա��ϵ��\n";
				break;
		}
	}
	s += "[����:user_package_buy_list]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
