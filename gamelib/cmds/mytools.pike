#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "������װ����\n";
	s += "[���������ԣ�:myinfo]\n";
	s += "[������״̬��:myhp]\n";
	//s += "����ǿ�ȣ�"+me->query_low_attack_desc()+"-"+me->query_high_attack_desc()+"\n";
	////////////////////////////////////////////////////////////////////////////////
	//s += "�����ٶȣ�"+me->query_speed_power("main")+"("+me->query_speed_power("other")+")\n";
	////////////////////////////////////////////////////////////////////////////////
	//s += "����ǿ�ȣ�"+me->query_defend_power()+"\n";
	////////////////////////////////////////////////////////////////////////////////
	//s += "��������\n";
	/*
	string user_equip_main_weapon = me->query_equiped_main_weapons();
	string user_equip_other_weapon = me->query_equiped_other_weapons();
	s += "�����֣�";
	if(user_equip_main_weapon&&sizeof(user_equip_main_weapon)){
		s += user_equip_main_weapon;//+"\n";
		s += "�˺���"+me->query_low_attack("base_main")+"-"+me->query_high_attack("limit_main")+"\n";
		s += "�ٶȣ�"+me->query_speed_power("main")+"\n";
	}
	else
		s += "��\n";
	//////////////////////////
	s += "�����֣�";
	if(user_equip_other_weapon&&sizeof(user_equip_other_weapon)){
		s += user_equip_other_weapon;
		s += "�˺���"+me->query_low_attack("base_other")+"-"+me->query_high_attack("limit_other")+"\n";
		s += "�ٶȣ�"+me->query_speed_power("other")+"\n";
	}
	else
		s += "��\n";
	s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "�۷��ߣ�\n";
	string user_equip_armor = me->query_equiped_armor();
	if(user_equip_armor&&sizeof(user_equip_armor))
		s += user_equip_armor;
	else
		s += "��\n";
	s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "�����Σ�\n";
	string user_equip_jewelry = me->query_equiped_jewelry();
	if(user_equip_jewelry&&sizeof(user_equip_jewelry))
		s += user_equip_jewelry;
	else
		s += "��\n";
	s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "�������\n";
	string user_equip_decorate = me->query_equiped_decorate();
	if(user_equip_decorate&&sizeof(user_equip_decorate))
		s += user_equip_decorate;
	else
		s += "��\n";
	////////////////////////////////////////////////////////////////////////////////
	*/
	s += me->view_equip();
	//s += "[������Ϸ:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//write(s);
	return 1;
}
