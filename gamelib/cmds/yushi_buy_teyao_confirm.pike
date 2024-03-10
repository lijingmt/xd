#include <command.h>
#include <gamelib/include/gamelib.h>
#define TEYAO_PATH ROOT "/gamelib/clone/item/teyao/"
//ȷ����ʯ�����ĳҩƷ
//arg =   name       yushi_rareLevel    need_amount       buy_num
//     ҩƷ�ļ���    ������ʯ��ϡ�ж�   ��ʯ�ĸ���  ����ĸ���

int main(string arg)
{
	object me = this_player();
	string teyao_name = "";
	int rarelevel = 0;
	int need_amount = 0;
	int need_money = 0;//add by caijie 08/06/10
	int flag = 0;//add by caijie 08/06/10 0��ʾ�ϵ���ҩ 1��ʾ����ҩ
	int buy_num = 0;
	string s_buy_num = "";
	string s = "";
	string s_log = "";
	string c_log = "";//ͳ��ʹ�õ���־ evan added 2008.07.10
	sscanf(arg,"%s %d %d %d %d %s",teyao_name,rarelevel,need_amount,need_money,flag,s_buy_num);
	if(flag==0)
		sscanf(s_buy_num,"no=%d",buy_num);
	else buy_num = 1;
	object teyao;
	string need_yushi = YUSHID->get_yushi_name(rarelevel);
	//���������ϴ�����ʯ�ĸ���
	int have_num = YUSHID->query_yushi_num(me,rarelevel);
	int have_money = me->query_account();
	//���㵽����ܹ������ҩ��������
	int can_num = have_num/need_amount;
	//��caijie�����2008/06/10
	if(need_money>0){
		need_money = need_money*100;
		int have_money = me->query_account();
		int m_can_num = have_money/need_money;
		can_num = min(can_num,m_can_num);
	}
	//end
	//��Ҫ���ж�
	if(buy_num<1 || buy_num>20)
		s += "�������󣡹������������1��20֮��\n";
	else if(can_num<=0 || can_num<buy_num)
		s += "������ʯ���߻ƽ𲻹������޷�����ָ����Ŀ�Ĵ���ҩƷ\n";
	else{
		if(flag==1){
			if(me->query_level()>30){
				s += "����ҩֻ��30�����µ�������ۣ���ļ���̫�ߣ����ܹ����ҩƷ\n";
				s += "\n";
				s += "[����:yushi_buy_teyao_list exp]\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			if(me->get_once_day[teyao_name]==1){
				s += "��ҩƷһ��ֻ�ܹ���һ��\n";
				s += "\n";
				s += "[����:yushi_buy_teyao_list exp]\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			me->get_once_day[teyao_name] = 1;
		}
		mixed err;
		err=catch{
			teyao = clone(TEYAO_PATH+teyao_name);
		};
		if(!err && teyao){
			teyao->amount = buy_num;
			if(me->if_over_load(teyao)){
				s += "���������Ʒ�������޷���װ�¸���\n";
			}
			else{
				//ÿ����һ�����Ϳ۳�һ�������ĵ���ʯ��
				me->remove_combine_item(need_yushi,need_amount*buy_num);
				me->del_account(need_money);
				s += "���׳ɹ���������"+teyao->query_short()+"\n";
				int val = 1;
				if(need_yushi == "xianyuanyu")
					val = 10;
				else if(need_yushi == "linglongyu")
					val = 100;
				else if(need_yushi == "biluanyu")
					val = 1000;
				else if(need_yushi == "xuantianbaoyu")
					val = 10000;
				int cost_reb = need_amount*buy_num*val;
				string teyao_namecn = teyao->query_name_cn();
				string consume_time = MUD_TIMESD->get_mysql_timedesc();
				string cost = ""+(need_amount*buy_num)+"|"+need_yushi;
				//s_log += "insert xd_consume (consume_time,user_id,user_name,area,type,cost,get_item,get_item_num,get_item_cn,cost_reb) values ('"+consume_time+"','"+me->query_name()+"','"+me->query_name_cn()+"','"+GAME_NAME_S+"','teyao','"+cost+"','"+teyao_name+"',"+buy_num+",'"+teyao_namecn+"',"+cost_reb+");\n";
				c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][teyao]["+teyao_name+"]["+teyao_namecn+"]["+buy_num+"]["+cost_reb+"]["+flag+"]\n";
				teyao->move_player(me->query_name());
			}
		}
		else{
			s += "����ʧ�ܣ��޷��õ�����ҩƷ������ϵ��Ϸ���������ǽ�����Ϊ����\n";
		}
		/*
		if(s_log != ""){
			string now=ctime(time());
			Stdio.append_file(ROOT+"/log/fee_log/yushi_use-"+MUD_TIMESD->get_year_month_day()+".log",s_log);
		}
		*/
		if(c_log != ""){                                                                           
			Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
		}
	}
	s += "[��������:yushi_buy_teyao_list exp]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
