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
	int level = 0;
	sscanf(arg,"%d",level);
	string vip_name = VIPD->get_vip_name(level);
	string vip_desc = VIPD->get_vip_desc(level);
	int vip_cost = VIPD->get_vip_cost(level);
	s += vip_name + "\n\n";
	s += vip_desc + "\n\n";
	s += "��Ҫ"+ YUSHID->get_yushi_for_desc(vip_cost*10)+"\n"; 
	s += "[����:vip_service_app_confirm.pike "+level+"]\n\n";
	s += "[����:yushi_myzone.pike]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
