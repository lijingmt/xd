#include <command.h>
#include <gamelib/include/gamelib.h>
/*
�����������ҳ��
auther: evan
2008.07.16
*/
int main(string arg)
{
	object me = this_player();
	string s = "***��Ա����***\n\n";
	s += VIPD->get_vip_state_des_withoutlink(me);
	int state = VIPD->get_vip_state(me);
	if(state)//����ǻ�Ա
	{
		int level = me->query_vip_flag();
		int vip_cost = VIPD->get_vip_cost(level);
		vip_cost = vip_cost*9/10;//����9���Ż�
		string cost_des = YUSHID->get_yushi_for_desc(vip_cost*10);
		string vip_name = VIPD->get_vip_name(level);
		string vip_desc = VIPD->get_vip_desc(level);
		s += "����"+vip_name+",������������9���Żݣ�ֻ��"+cost_des+"\n(ע�⣺���ѽ�ʹ��Ա�ʸ���ԭ�л�����˳��30��)\n"; 
		s += "[����:vip_service_extend_confirm "+ vip_cost +"]\n\n";
	}
	else//�ǻ�Ա�����������ʾ
	{
		s += VIPD->get_vip_state_des(me);
	}
	s += "[����:vip_service_list.pike]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
