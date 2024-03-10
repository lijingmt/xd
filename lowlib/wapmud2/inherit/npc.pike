#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit LOW_F_HIDDEN;
inherit MUD_NPC;
inherit MUD_F_GHOST;//��Ϸwap����������
inherit WAP_F_VIEWSTACK;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_INVENTORY;
inherit WAP_F_VIEW_PICTURE;
inherit WAP_F_VIEW_SKILLS;//��Ϸwap���ܱ��ֲ�
inherit WAP_F_FIGHT;

array(string) query_command_prefix(){
		return ({SROOT+"/wapmud2/cmds/"})+({COMMAND_PREFIX});
}

//boss����ϵͳ ��һ���ͷ�ʱ��/��ȴʱ��:��������
mapping(string:string) boss_skills = ([]);


void create(){
	//������Ҫ����
	life = 10;//����
	life_max = 10;//��������
	mofa = 10;//����
	mofa_max = 10;//��������
	_str = 1;//����
	_dex = 1;//����
	_think = 1;//����
	_lunck = 1;//����
	_appear = 20;//��ò
	//������������
	_npcLevel = 1;//Ĭ��Ϊһ��
	_levelup = 0;//Ĭ��Ϊ�����Զ�����
	_meritocrat = 0;//Ĭ��Ϊ�Ǿ�Ӣ��
	_boss = 0;//Ĭ��Ϊ��boss�ȼ���
	_rare = 0;//Ĭ��Ϊ��ϡ�й�
	_domestication = 0;//Ĭ��Ϊ����ѱ��
	_autolevel = 0;//Ĭ��Ϊ�����Զ������ȼ�
	_tasknpc = 0;//Ĭ��Ϊ������npc
	_killauto = 0;//Ĭ��Ϊ���Զ���������Npc
	_skillsable = 0;//Ĭ��Ϊû�м���
	_troth = 0;//Ĭ��Ϊ�ҳ϶�Ϊ0
	_randomwords = "ʲô����\n";//�������
	_equiped = 1;//Ĭ�Ͽ���װ����Ʒ
	_flushtime = 5*60;//Ĭ��5����ˢ��һ��
	_hate = 0;//Ĭ�ϳ��ֵΪ��
	_fury = 0;//�񱩼���Ϊ��
	_recovery = 20;//Ĭ�ϻ�Ѫ����ϵ��
}
string query_links(void|int count){
	string kill ="";
	//if(this_object()->is_item())
	//	kill += "[����:frisk "+this_object()->name+" "+count+"]\n[ɱ¾:kill "+this_object()->name+" "+count+"]\n";
	return kill+::query_links();
}
//���ﷵ�ص���npc�һ�ѡ�����ӱ�����󷵻ص�������_randomwords���Է���д�õ�
//npc��һ�仰������д��deamons������npc����Ӫ�����壬�Ա���ʹ���ȥ���õ�һ��
//���������˼�ĶԻ����ݣ�Ҳ�Ǻܲ���ġ�
string query_words(){
	//���ݹ���ְҵ��ͬ���ز�ͬ���������
	string rst = "";
	if(this_object()->query_raceId()=="human"&&this_object()->query_profeId()=="humanlike"){
		rst += "����ʲô���飿\n";
	}
	else if(this_object()->query_raceId()=="monst"&&this_object()->query_profeId()=="humanlike"){
		rst += "����ʲô���飿\n";
	}
	else if(this_object()->query_profeId()=="humanlike"){
		rst += "�������ң�\n";
	}
	else if(this_object()->query_profeId()=="beast"){
		rst += "��~~~\n";
		rst += "��������֪������˵Щʲô����������\n";
	}
	else if(this_object()->query_profeId()=="bird"){
		rst += "֨֨~~~\n";
		rst += "��������֪������˵Щʲô����������\n";
	}
	else if(this_object()->query_profeId()=="fish"){
		rst += "......\n";
		rst += "��������֪������˵Щʲô����������\n";
	}
	else if(this_object()->query_profeId()=="bugs"){
		rst += "˻˻~~~\n";
		rst += "��������֪������˵Щʲô����������\n";
	}
	else if(this_object()->query_profeId()=="amphibian"){
		rst += "˻˻~~~\n";
		rst += "��������֪������˵Щʲô����������\n";
	}
	return rst;
}
string view_equip(){
	object me = this_object();
	string s = "";
	//s += "��������\n";
	string user_equip_main_weapon = me->query_equiped_main_weapons();
	string user_equip_other_weapon = me->query_equiped_other_weapons();
	//s += "�����֣�";
	if(user_equip_main_weapon&&sizeof(user_equip_main_weapon)){
		s += "�����֣�";
		s += user_equip_main_weapon;//+"\n";
	}
	if(user_equip_other_weapon&&sizeof(user_equip_other_weapon)){
		s += "�����֣�";
		s += user_equip_other_weapon;
	}
	string user_equip_armor = me->query_equiped_armor();
	if(user_equip_armor&&sizeof(user_equip_armor)){
		s += "�۷��ߣ�\n";
		s += user_equip_armor+"\n";
	}
	//else
	//	s += "\n";
	//s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	//s += "�����Σ�\n";
	string user_equip_jewelry = me->query_equiped_jewelry();
	if(user_equip_jewelry&&sizeof(user_equip_jewelry)){
		s += "�����Σ�\n";
		s += user_equip_jewelry+"\n";
	}
	//else
	//	s += "\n";
	//s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	//s += "�������\n";
	string user_equip_decorate = me->query_equiped_decorate();
	if(user_equip_decorate&&sizeof(user_equip_decorate)){
		s += "�������\n";
		s += user_equip_decorate+"\n";
	}
	//else
	//	s += "\n";
	return s;
}

//����װ������������
string query_equiped_main_weapons(){
	string out="";
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob&&ob["equiped"]&&(ob->query_item_kind()=="double_main_weapon"||ob->query_item_kind()=="single_main_weapon")){
			string s_file = file_name(ob);
			out+="["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
		}
	}
	return out;
}
//����װ���ĸ�������
string query_equiped_other_weapons(){
	string out="";
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_kind()=="single_other_weapon"){
			string s_file = file_name(ob);
			out+="["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
		}
	}
	return out;
}
//����װ���ķ���
string query_equiped_armor(){
	string out="";
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_type()=="armor"){
			string s_file = file_name(ob);
			if(ob->query_item_kind()=="armor_head")
				out+="��ͷ����["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
			if(ob->query_item_kind()=="armor_cloth")
				out+="���ز���["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
			if(ob->query_item_kind()=="armor_waste")
				out+="���󲿣�["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
			if(ob->query_item_kind()=="armor_hand")
				out+="���ֲ���["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
			if(ob->query_item_kind()=="armor_thou")
				out+="���Ȳ���["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
			if(ob->query_item_kind()=="armor_shoes")
				out+="���Ų���["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
		}
	}
	return out;
}

//����װ��������
string query_equiped_jewelry(){
	string out="";
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_type()=="jewelry"){
			if(ob->query_item_kind()=="jewelry_ring")
				out+="����ָ��"+ob->query_name_cn()+"\n";
			if(ob->query_item_kind()=="jewelry_neck")
				out+="��������"+ob->query_name_cn()+"\n";
			if(ob->query_item_kind()=="jewelry_bangle")
				out+="������"+ob->query_name_cn()+"\n";
		}
	}
	return out;
}
//����װ��������
string query_equiped_decorate(){
	string out="";
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_type()=="decorate"){
			if(ob->query_item_kind()=="decorate_manteau")
				out+="��������"+ob->query_name_cn()+"\n";
			if(ob->query_item_kind()=="decorate_thing")
				out+="���Ҽ���"+ob->query_name_cn()+"\n";
			if(ob->query_item_kind()=="decorate_tool")
				out+="����Ʒ��"+ob->query_name_cn()+"\n";
		}
	}
	return out;
}
string query_npc_status(int player_level){
	string s = "";
	/*
	if(this_object()->_meritocrat)
		s += "(��Ӣ)\n";
	if(this_object()->_boss)
		s += "(����)\n";
	*/
	if(player_level<=0)
		return s + "��������\n��������";
	else{
		int diff = this_object()->query_level()-player_level; 
		if(diff>=5)
			return s + "��������\n��������";
		else
			return s + "������"+this_object()->get_cur_life()+"\n������"+this_object()->get_cur_mofa();
	}
	return s += "��������\n��������";
}
/*
string query_dog_attr()
{
	object room = environment(this_object());
	string s = "";
	string st = room->query_dog();
	if(st!=""&&(st/",")[0]=="1"){
		array(string) tmp = st/",";
		//s += "������"+(int)tmp[2]+"\n������"+(int)tmp[3]+"\n������"+(int)tmp[4]+"\n���ݣ�"+(int)tmp[5];
		s += "������"+(int)tmp[3]+"\n������"+(int)tmp[4]+"\n���ݣ�"+(int)tmp[5];
	}
	return s;
}
*/
