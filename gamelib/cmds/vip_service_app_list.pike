#include <command.h>
#include <gamelib/include/gamelib.h>
/*
�������ѡ��ҳ��
auther: evan
2008.07.16
*/
int main(string arg)
{
	object me = this_player();
	string s = "***��Ա����***\n\n";
	s += "��ѡ����Ҫ����Ļ�Ա���:\n";
	mapping vip_name = VIPD->get_vip_name_map();
	mapping vip_cost = VIPD->get_vip_cost_map();
	int num = sizeof(vip_name);
	int num2 = sizeof(vip_cost);
	if(num>num2) num=num2;
	for(int i=1;i<=num;i++)
	{
		s += "["+vip_name[i]+"("+ YUSHID->get_yushi_for_desc(vip_cost[i]*10) +"):vip_service_app_detail "+(string)i+"]\n";
	}
	
	s += "\n[����:vip_service_list.pike]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
