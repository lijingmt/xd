#include <command.h>
#include <gamelib/include/gamelib.h>
//�����滻��ֻ����С���滻���
int main(string arg)
{
	object me = this_player();
	string s="";
	string tmp_s = "";
	string s_log = "";
	string s_rep_count = "";//��������
	string type = "";//���ͣ�������ֿ�
	int pac_size1 = 0;//�滻ǰ�ı�����С
	int pac_size2 = 0;//�滻��ı�����С
	int need_yushi = 0;//����Ҫ����ʯ
	int rep_count = 0;//�����־��0���鿴  1��ȷ������  2:��������
	sscanf(arg,"%s %d %d %d %s",type,pac_size1,pac_size2,need_yushi,s_rep_count);
	sscanf(s_rep_count,"no=%d",rep_count);
	if(type=="beibao") tmp_s += "����";
	if(type=="cangku") tmp_s += "�ֿ�";
	//werror("------rep_count="+rep_count+"---\n");
	if(me->package_expand[type][pac_size1]&&rep_count>0&&rep_count<=me->package_expand[type][pac_size1]){
		int yushi = need_yushi*rep_count;
		int buy_result = BUYD->do_trade(me,yushi,0);
		switch(buy_result){
			case 0:
				s += "�����ϵ���ʯ������\n";
				break;
			case 1:
				s += "�����ϵĽ�Ǯ������\n";
				break;
			case 2..3:
				if(!me->package_expand[type][pac_size2]){
					me->package_expand[type][pac_size2]=rep_count;
				}
				else{
					me->package_expand[type][pac_size2]+=rep_count;
				}
				me->package_expand[type][pac_size1]-=rep_count;
				if(me->package_expand[type][pac_size1]<=0)m_delete(me->package_expand[type],pac_size1);
				//string name_cn = pac_size+"��"+tmp_s;
				s_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"]["+type+"]["+pac_size1+type+"]["+pac_size2+type+"]["+rep_count+"]["+need_yushi+"][0]\n";
				Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",s_log);
				//s += "���ѳɹ��á�p"+rep_count+"pac_size1+"���"+tmp_s+"�滻"+pac_size2+"���"+tmp_s+"\n\n";
				s += "���ѳɹ���"+rep_count+"��"+pac_size1+"���"+tmp_s+"�滻��"+rep_count+"��"+pac_size2+"���"+tmp_s+"���ҿ۳�����"+YUSHID->get_yushi_for_desc(yushi)+"\n\n";
				break;
			default:
				s += "ϵͳ�����ˣ���͹���Ա��ϵ��\n";
				break;
		}
	}
	else {
	//������������ڱ���ӵ�еı�������
		//s += "������û����ô���"+pac_size1+"��"+tmp_s+"����������ȷ����\n";
		s += "������������ȷ����\n";
		s += "[��������:user_package_replace_detail "+type+" "+pac_size1+" "+pac_size2+" "+need_yushi+"]\n";
		s += "[����:user_package_replace_list "+type+" "+pac_size2+"]\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	s += "[����:user_package_buy_list]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
