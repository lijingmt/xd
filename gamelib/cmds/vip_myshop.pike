#include <command.h>
#include <gamelib/include/gamelib.h>

//�ɵ���Ա�����

int main(string arg){
	object me = this_player();
	string s = "�ɵ���Ա��\n\n";
	s += "[��Ա����:vip_service_list]\n";
	s += "[��Ա������:vip_myzone]\n";
	s += "\n";
	s += "[���������:yushi_myzone]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
