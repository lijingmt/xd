#include <command.h>
#include<wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	string s_log = "";
	string c_log = "";
	string uid = arg;
	int yushi_level = 1;
	string yushi_name = "suiyu";
	int need_yushi = 2;
	//��������������ĸ���
	int have_yushi = YUSHID->query_yushi_num(me,yushi_level);
	if(have_yushi<need_yushi){
		s += "��Ŀǰ����ʯ����֧�����β�����\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	int result = me->start_spy(uid);
	switch(result){
		case 0:
			s += "�����Ѿ��ڹ�ע״̬���ˣ���֪��������Ǯ�ˣ���Ҳ������ô�˷Ѱ�!\n";
			break;
		case 1:
			s += "��ϲ��ȷ�ϳɹ�����������1Сʱ�ڿ�������ҵ����١�\n";
			me->remove_combine_item(yushi_name,need_yushi);
			string cost = need_yushi+"|"+yushi_name;
			int cost_reb = need_yushi;
			string consume_time = MUD_TIMESD->get_mysql_timedesc();
			//s_log += "insert xd_consume (consume_time,user_id,user_name,area,type,cost,get_item,get_item_num,get_item_cn,cost_reb) values ('"+consume_time+"','"+me->query_name()+"','"+me->query_name_cn()+"','"+GAME_NAME_S+"','guanzhu','"+cost+"','"+uid+"',1,' ',"+cost_reb+");\n";
			c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][guanzhu]["+uid+"][][1]["+cost_reb+"][0]\n";
			break;
	}
	/*
	if(s_log!=""){
		Stdio.append_file(ROOT+"/log/fee_log/yushi_use-"+MUD_TIMESD->get_year_month_day()+".log",s_log);
	}
	*/
	if(c_log!=""){
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
