#include <command.h>
#include <gamelib/include/gamelib.h>
/*
��Ա������ҳ
auther: evan
2008.07.16
*/
int main(string arg)
{
	object me = this_player();
	string s = "***��Ա�Ż�����***\n\n";
	s += "0������һ����(30��)������Ŀ���ʹ�÷���\n";
	s += "1���ѻ�û�Ա�ʸ����Ҳ���Ի���һ����ʯ������������\n";
	s += "2����Ա�ڹ���֮������������Ա,�����������۸�6���Ż�\n";
	s += "3����Ա�ڼ����ѿ�������9���Ż�\n\n\n";

	s += VIPD->get_vip_state_des(me);

	s += "\n[����:vip_service_list.pike]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
