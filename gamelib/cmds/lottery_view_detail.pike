//��Ҳ鿴��ϸ��Ʒ��Ϣ��������ü���ĳ齱
//arg = lv �齱�ļ���
#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	int lv = (int)arg;
	s += LOTTERYD->query_lottery_award_detail(lv);
	s += "[����:lottery_view_list]\n";
	s += "[�����:yushi_myzone]\n";
	s +="[������Ϸ:look]\n";
	write(s);
	return 1;
}
