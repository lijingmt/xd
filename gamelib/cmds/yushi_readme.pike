#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//��ʯ��Ҳ����ӿ�
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "������ȡ����˵����\n";
	s += "�û�����50Ԫ�����ɻ��5��������\n";
	s += "��������qq:1811117272\n";
	//s += "[�����п�������ȡ����˵��:szx_readme]\n";
	//s += me->query_mini_picture_url("decorate11")+"[���ž�����ȡ����˵��:yushi_msg_readme]\n";
	//s += me->query_mini_picture_url("decorate11")+"[���о�����ȡ����˵��:add_big_fee_des]\n";
	s += "[����:yushi_myzone]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
