#include <command.h>
#include <gamelib/include/gamelib.h>

//���ŵ���ָ��

int main(string arg)
{
	object me = this_player();
	string s = "";
	object room;
	/*
	object room = environment(me);
	string master_name = room->masterId;
	object master = find_player(master_name);
	*/
	string my_name = me->query_name();
	if(HOMED->if_have_home(my_name)){
		room = HOMED->query_room_by_masterId(my_name,"main");
	}
	string msg = "";
	string kd_name = "";//������ҵ�id
	string result = "";
	sscanf(arg,"%s %s",kd_name,result);
	object kn_user = find_player(kd_name);
	if(!kn_user){
		msg += "������Ѿ��뿪\n";
		msg += "[������Ϸ:look]\n";
		write(msg);
		return 1;
	}
	if(result=="yes"){
		s += me->query_name_cn()+"�򿪴��ţ����ҵĻ�ӭ��ĵ���\n";
		s += "\n[����:home_visit "+me->query_name()+"]\n";
		//s += "[����뿪:look]\n";
		kn_user->home_rights[1]=my_name;
		msg += "�����ĵĸ�"+kn_user->query_name_cn()+"���˴��ţ����ҵĻ�ӭ���ĵ���\n";
	}
	else if(result=="no"){
		s += me->query_name_cn()+"����������û���д��㣬���������ɡ�\n";
		//s += "[��������:home_knock_door "+me->query_name()+"]\n";
		//s += "[�뿪:look]\n";
		msg += "���ܾ���"+kn_user->query_name_cn()+"������\n";
	}
	//s += "[�뿪����:home_leave "+ room->query_slotName()+" "+room->query_flatName() +"]\n\n";
	msg += "[����:look]\n";
	write(msg);
	//me->command("look");
	tell_object(kn_user,s);
	return 1;
}
