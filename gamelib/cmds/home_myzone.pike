#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//������ü�԰�����Ϣ����ҳ��
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "**��԰����**\n";
	s += "�㵱ǰ�ļ�԰�ȼ�Ϊ:"+HOMED->get_home_level(me->query_name())+"��\n";
	s += "��ѡ����Ҫ���еĲ���:\n";
	s += "[ȡ��:home_rename_submit]\n";
	s += "[װ��:home_install_door]\n";
	s += "[��������:home_redesc_submit]\n";
	//s += "[��ӷ���:home_functionroom_buy_list home_base]\n";
	s += "[������:home_functionroom_buy_list]\n";
	if(HOMED->if_have_shopLicense(me->query_name()))
		s += "[˽��С��:home_move sijiaxiaodian]\n";
	s += "[�ҵĹ���:home_mydog]\n\n";
	s += "[����:look]\n";
	write(s);
	return 1;
}
