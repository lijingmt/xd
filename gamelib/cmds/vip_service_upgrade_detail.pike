#include <command.h>
#include <gamelib/include/gamelib.h>
/*
��Ա������ϸҳ��
auther: evan
2008.07.18
*/
int main(string arg)
{
	object me = this_player();
	string s = "***��Ա����***\n\n";
	int old_level = me->query_vip_flag();//��ǰ����
	int new_level = 0;//������ļ���
	sscanf(arg,"%d",new_level);
	string new_vip_desc = VIPD->get_vip_desc(new_level);
	mapping vip_name = VIPD->get_vip_name_map();
	mapping vip_cost = VIPD->get_vip_cost_map();
	string new_desc = VIPD->get_vip_desc(new_level);
	s += vip_name[new_level] + "\n\n";
	s += new_desc+"\n";

	int state = VIPD->get_vip_state(me);
	int cost = ((int)vip_cost[new_level]-(int)vip_cost[old_level]);
	if(state==2||state==3)
	{
		cost=cost*6/10;//��Ա���޹��������6���Ż�
	}
	s += "�㼴������Ϊ"+vip_name[new_level]+",��Ҫ����"+ YUSHID->get_yushi_for_desc(cost*10)+"\n\n";
	s += "[ȷ��:vip_service_upgrade_confirm.pike "+new_level+" "+cost+"]\n";
	s += "[����:vip_service_upgrade_list.pike]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
