#include <command.h>
#include <gamelib/include/gamelib.h>
//�̽�ʯ�����ӿ�
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "��ѡ��������Ҫ��Ч������ʱ��: \n";
	s += "\n";
	s += "[60����(1������Ե��):ljs_chongzhi_confirm 3600 10 0]\n";
	s += "[180����(2������Ե��9��������):ljs_chongzhi_confirm 10800 29 0]\n";
	s += "[300����(4������Ե��8��������):ljs_chongzhi_confirm 18000 48 0]\n";
	s += "[480����(7������Ե��7��������):ljs_chongzhi_confirm 28800 77 0]\n";
	s += "\n";
	s += "[����:inventory]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
