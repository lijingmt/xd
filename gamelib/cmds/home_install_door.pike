#include <command.h>
#include <gamelib/include/gamelib.h>

//���ŵ���ָ��

int main(string arg)
{
	object me = this_player();
	string s = "";
	object room = environment(me);
	string st = room->query_door();
	if(arg=="no"){
		s += "��������װ��\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(st !="" && !arg){
		array(mixed) tmp = st/",";
		if(tmp[0]=="1"){
			string hm_dr_nm = tmp[1]; //�����Ѿ���װ����
			object hm_dr_ob = clone(ITEM_PATH+hm_dr_nm);
			s += "���ļ��Ѿ�װ��һ��"+hm_dr_ob->query_name_cn()+"����ȷ��Ҫ������һ������\n";
			s += "[ȷ��:home_install_door yes]  [����:home_install_door no]\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
	}
	string s_door = ITEMSD->daoju_list(me,"home_install_conform","door");
	if(!sizeof(s_door)){
		s += "����û���ţ����ӻ���������һ�Ȱ�\n";
		 me->write_view(WAP_VIEWD["/emote"],0,0,s);
		 return 1;
	}
	s += "����������װ��ʲô�����ţ�\n";
	//s += ITEMSD->daoju_list(me,"door_destroy_confirm","hammer",arg);
	s += s_door;
	s += "\n\n";
	s += "[������װ:popview]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
