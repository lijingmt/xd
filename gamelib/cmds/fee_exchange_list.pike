#include <command.h>
#include <gamelib/include/gamelib.h>
//������Ϸ���Ҷһ����ܵ�ָ��
int main(string arg)
{
	object me = this_player();
	string s = "[url ��������:http://wap.doggame.net/pokegame/index.jsp]\n��Ϸ��һ�\n";
	s += "[�˵��:fee_exchange_readme]\n";
	s += "�������������ȡ������������ó���Ϊ��һ�����ʯ\n";
	s += "[��ȡ�һ�������ʯ:fee_exchange_fetch_list]\n";
	s += "Ҳ���Խ���ʯ�һ�Ϊ�������Ƶĳ���\n";
	s += "[�һ����Ƴ���:fee_exchange_to_detail qp0]\n";
	s += "--------\n";
	s += "[����:yushi_myzone]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
