#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//��Ա�Żݹ���ƽ̨
int main(string arg)
{
	object me = this_player();
	string s = "";
	mapping(string:int) time = localtime(time());
	int hour = time["hour"];
	s += "**��Ա�ع���**\n\n";
	s += "---�����---\n";
	s += "[��ʯ:vip_myzone_free_list baoshi 1]\n";
	s += "[��ҩ:vip_myzone_free_list teyao 1]\n\n";

	s += "---�ۿ���---\n";
	s += "[��ʯ:vip_myzone_off_list baoshi 1]\n";
	s += "[����:vip_myzone_off_list other 1]\n";
	s += "[��ҩ:vip_myzone_off_list teyao 1]\n";

	s += VIPD->get_vip_state_des(me);
	s += "\n[����:yushi_myzone]\n";
	s += "\n[������Ϸ:look]\n";
	write(s);
	return 1;
}
