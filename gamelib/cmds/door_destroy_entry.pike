#include <command.h>
#include <gamelib/include/gamelib.h>

//���ŵ���ָ�� ��ʱ����

int main(string arg)
{
	object me = this_player();
	string s = "";
	object room = environment(me);
	if(room->query_door()==""){
		s += "����ҵ����Ѿ����ƻ��ˣ���û��Ҫ���˷Ѵ���,�������Ҳ�������ѱ�ϴ��һ��\n";
		s += "\n[��ȥ����:home_enter main]\n";
		s += "[���ˣ����˷�ʱ��:look]\n";
		write(s);
		return 1;
	}
	/*
	string dr_nm = room->query_door();
	object dr_ob = (object)(ITEM_PATH+dr_nm);
	s += dr_ob->query_name_cn()+"\n";
	s += dr_ob->query_picture_url()+"\n��̶ȣ�"+dr_ob->value+"\n"+dr_ob->query_desc()+"\n";
	s += "\n";
	s += "[����:door_destroy_detail]\n";
	*/
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
