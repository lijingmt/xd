#include <command.h>
#include <gamelib/include/gamelib.h>
//����һ���ĳ��Ϸ������ҳ��ָ������ṩ�������ƣ��ṩ��������ʺźͶһ����
//arg = ��Ϸ������
int main(string arg)
{
	object me = this_player();
	string game_id = arg;
	string to_game_cn = FEE_EXCHANGED->query_to_game_cn(game_id);
	string s = "��ѡ������Ե��һ���"+to_game_cn+"�ĳ���\n";
	s += "��ע�⡿��15��(����15��)���µ���Ҳ��ܶһ�����\n";
	s += "��ע�⡿��ÿ��������ֻ�ܶһ�100��Ե��\n";
	s += "�һ�������1��Ե�� = 1000����\n";
	s += "������һ���"+to_game_cn+"������ʺţ�\n";
	s += "��������ȷ�Ҵ��ڵ��˺ţ�����Է��޷���ã�ע�⣺�����ʺ�Ϊ���Ƶ�ע���ʺţ�\n";
	s += "[string tn:...]\n";
	s += "������Ҫ�һ�����Ե�������\n";
	s += "[int fe:...]\n";
	s += "[submit ȷ��:fee_exchange_to_confirm 0 "+game_id+" ...]\n";
	s += "��Ŀǰӵ�С�����Ե��"+YUSHID->query_yushi_num(me,2)+"\n";
	s += "--------\n";
	string game_tmp = game_id[0..1];
	s += "[����:fee_exchange_list]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
