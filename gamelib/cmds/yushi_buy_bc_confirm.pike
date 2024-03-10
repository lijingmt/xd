#include <command.h>
#include <gamelib/include/gamelib.h>
#define ITEM_PATH ROOT "/gamelib/clone/item/other/"
//ʵ����ʯ����ǧ������
//arg =   name       yushi_rareLevel    need_amount       buy_num
//     ��ʯ�ļ���    ������ʯ��ϡ�ж�   ��ʯ�ĸ���  ����ĸ���

int main(string arg)
{
	object me = this_player();
	string bc_name = "";
	int rarelevel = 0;
	int need_amount = 0;
	int buy_num = 0;
	string s_buy_num = "";
	string s = "";
	string s_log = "";
	string c_log = "";//ͳ��ʹ�õ���־ evan added 2008.07.10
	sscanf(arg,"%s %d %d %s",bc_name,rarelevel,need_amount,s_buy_num);
	sscanf(s_buy_num,"no=%d",buy_num);
	object bc;
	string need_yushi = YUSHID->get_yushi_name(rarelevel);
	//���������ϴ�����ʯ�ĸ���
	int have_num = YUSHID->query_yushi_num(me,rarelevel);
	//���㵽����ܹ�����˴�������������
	int can_num = have_num/need_amount;
	/*
	if(need_money>0){
		need_money = need_money*100;
		int have_money = me->query_account();
		int m_can_num = have_money/need_money;
		can_num = min(can_num,m_can_num);
	}
	//end
	*/
	//��Ҫ���ж�
	int res_num = BROADCASTD->query_num(bc_name);
	if(bc_name=="qianlichuanyinfu" && (buy_num<1 || buy_num>res_num))
		s += "��������ǧ�ﴫ����ֻʣ��"+res_num+"���ˣ��������������1��"+res_num+"֮��\n";
	else if(can_num<=0 || can_num<buy_num)
		s += "������ʯ���������޷�����ָ����Ŀ�����\n";
	else{
		mixed err;
		err=catch{
			bc = clone(ITEM_PATH+bc_name);
		};
		if(!err && bc){
			bc->amount = buy_num;
			if(me->if_over_load(bc)){
				s += "���������Ʒ�������޷���װ�¸���\n";
			}
			else{
				//ÿ����һ�����Ϳ۳�һ�������ĵ���ʯ��
				me->remove_combine_item(need_yushi,need_amount*buy_num);
				s += "���׳ɹ���������"+bc->query_short()+"\n";
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
				string bc_namecn = bc->query_name_cn();
				string consume_time = MUD_TIMESD->get_mysql_timedesc();
				string cost = ""+(need_amount*buy_num)+"|"+need_yushi;
				//s_log += "insert xd_consume (consume_time,user_id,user_name,area,type,cost,get_item,get_item_num,get_item_cn,cost_reb) values ('"+consume_time+"','"+me->query_name()+"','"+me->query_name_cn()+"','"+GAME_NAME_S+"','chaunyinfu','"+cost+"','"+bc_name+"',"+buy_num+",'"+bc_namecn+"',"+cost_reb+");\n";
				if(bc_name=="qianlichuanyinfu")
					c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][chuanyinfu]["+bc_name+"]["+bc_namecn+"]["+buy_num+"]["+cost_reb+"][0]\n";
				else
					c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][mianzhanfu]["+bc_name+"]["+bc_namecn+"]["+buy_num+"]["+cost_reb+"][0]\n";
				bc->move_player(me->query_name());
				BROADCASTD->set_bc_num(bc_name,buy_num);
			}
		}
		else{
			s += "����ʧ�ܣ��޷��õ�ǧ�ﴫ����������ϵ��Ϸ���������ǽ�����Ϊ����\n";
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
	s += "[��������:yushi_buy_bc_detail "+bc_name+" "+rarelevel+" "+need_amount+"]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
