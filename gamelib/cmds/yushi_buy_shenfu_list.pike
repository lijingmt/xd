#include <command.h>
#include <gamelib/include/gamelib.h>

//���������ڵ���ָ��

int main(string arg)
{
	object me = this_player();
	string s = "���빺��ʲô���\n";
	mapping(string:int) time = localtime(time());
	int hour = time["hour"];
	/*
	if(hour>=18&&hour<=20)
		s += "[ǧ�ﴫ�������ͼ���ʱ����:yushi_buy_bc_detail qianlichuanyinfu 2 2](ʣ��"+BROADCASTD->query_num("qianlichuanyingfu")+"��)\n";
	else 
	*/
	s += "[ǧ�ﴫ����(�������):yushi_buy_bc_detail qianlichuanyinfu 2 1](ʣ��"+BROADCASTD->query_num("qianlichuanyingfu")+"��)\n";
	s += "[��ս��:yushi_buy_bc_detail mianzhanfu 1 5]\n";
	s += "\n";
	s += "[����:yushi_myzone]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
