#include <wapmud2.h>
inherit LOW_F_HIDDEN;//�����ת��
inherit MUD_USER;//��Ϸ�ܹ����û�����
inherit MUD_F_GHOST;//��Ϸwap����������
inherit WAP_F_FIGHT;//��Ϸwap��ս������
inherit WAP_F_VIEWSTACK;//��Ϸwap����ͼ��ջ
inherit WAP_F_VIEW_LINKS;//��Ϸwap�㳬���ӷ�ʽ
inherit WAP_F_VIEW_INVENTORY;//��Ϸwap���ɫ����Ʒ��ʾ��ʽ
inherit WAP_F_CATCH_TELL;//��Ϸwap����Ϣ����
inherit WAP_F_VIEW_PICTURE;//��Ϸwap��ͼƬ��ʾ
inherit WAP_F_VIEW_SKILLS;//��Ϸwap���ܱ��ֲ�
inherit WAP_F_QQLIST;//��Ϸwap�����ϵͳ
inherit WAP_F_MBOX;//��Ϸwap��������Ϣϵͳ

string user_mid;
string user_mkey;

string query_UNCONSCIOUS(){
	return unconscious_msg+"[�ȴ�:look]\n";
}
string query_LOGIN_MSG(){
	return "��¼��Ϣ�Ѿ����ڣ������½�����Ϸ\n[url ��go��ҳ:http://dogstart.com]\n[url wap����:http://tx.com.cn]\n";
}
string sid;
static int living_time=10*60;
void create(){
}
array(string) query_command_prefix(){
	return ({SROOT+"/wapmud2/cmds/"})+::query_command_prefix();
}
int setup(string arg){
	if(name=="null"){
		write(this_object()->query_LOGIN_MSG());
		destruct(this_object());
		return 0;
	}
	if(::setup(arg)==0){
		write(this_object()->query_LOGIN_MSG());
		destruct(this_object());
		return 0;
	}
	move(ROOT+"/"+this_object()->project+"/d/init");
	return 1;
}
void net_dead(){
	call_out(remove,living_time);
}
int reconnect(string arg){
	if(name=="null"||name==""){
		return 0;
	}
	return ::reconnect(arg);
}
string query_extra_links(void|int count){
	string weapon_usage="";
	return weapon_usage;
}
string query_links(void|int count){
	string kill ="";
	return kill+::query_links();
}

string view_equip(){
	object me = this_object();
	string s = "";
	s += "��������\n";
	string user_equip_main_weapon = me->query_equiped_main_weapons();
	string user_equip_other_weapon = me->query_equiped_other_weapons();
	s += "�����֣�";
	if(user_equip_main_weapon&&sizeof(user_equip_main_weapon)){
		s += user_equip_main_weapon;
	}
	else
		s += "\n";
	//////////////////////////
	s += "�����֣�";
	if(user_equip_other_weapon&&sizeof(user_equip_other_weapon)){
		s += user_equip_other_weapon;
	}
	else
		s += "\n";
	s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "�۷��ߣ�\n";
	string user_equip_armor = me->query_equiped_armor();
	if(user_equip_armor&&sizeof(user_equip_armor))
		s += user_equip_armor;
	else
		s += "\n";
	s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "�����Σ�\n";
	string user_equip_jewelry = me->query_equiped_jewelry();
	if(user_equip_jewelry&&sizeof(user_equip_jewelry))
		s += user_equip_jewelry;
	else
		s += "\n";
	s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "�������\n";
	string user_equip_decorate = me->query_equiped_decorate();
	if(user_equip_decorate&&sizeof(user_equip_decorate))
		s += user_equip_decorate;
	else
		s += "\n";
	return s;
}
//�������װ������������
string query_equiped_main_weapons(){
	object me = this_object();
	string out="";
	mapping(string:int) name_count=([]);
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob&&ob["equiped"]&&(ob->query_item_kind()=="double_main_weapon"||ob->query_item_kind()=="single_main_weapon")){
			string ob_name = ob->query_name();
			out+="["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			name_count[ob_name]++;
		}
	}
	return out;
}
//�������װ���ĸ�������
string query_equiped_other_weapons(){
	object me = this_object();
	string out="";
	mapping(string:int) name_count=([]);
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_kind()=="single_other_weapon"){
			string ob_name = ob->query_name();
			out+="["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			name_count[ob_name]++;
		}
	}
	return out;
}
//�������װ���ķ���
string query_equiped_armor(){
	object me = this_object();
	string out="";
	mapping(string:int) name_count=([]);
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_type()=="armor"){
			string ob_name = ob->query_name();
			if(ob->query_item_kind()=="armor_head")
out+="��ͷ����["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="armor_cloth")
				out+="���ز���["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="armor_waste")
				out+="���󲿣�["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="armor_hand")
				out+="���ֲ���["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="armor_thou")
				out+="���Ȳ���["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="armor_shoes")
				out+="���Ų���["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			name_count[ob_name]++;
		}
	}
	return out;
}
//�������װ��������
string query_equiped_jewelry(){
	object me = this_object();
	string out="";
	mapping(string:int) name_count=([]);
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_type()=="jewelry"){
			string ob_name = ob->query_name();
			if(ob->query_item_kind()=="jewelry_ring")
				out+="����ָ��["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="jewelry_neck")
				out+="��������["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="jewelry_bangle")
				out+="������["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			name_count[ob_name]++;
		}
	}
	return out;
}
//�������װ��������
string query_equiped_decorate(){
	object me = this_object();
	string out="";
	mapping(string:int) name_count=([]);
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_type()=="decorate"){
			string ob_name = ob->query_name();
			if(ob->query_item_kind()=="decorate_manteau")
				out+="��������["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="decorate_thing")
				out+="���Ҽ���["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="decorate_tool")
				out+="����Ʒ��["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			name_count[ob_name]++;
		}
	}
	return out;
}
/*//�õ�����Ƿ�ӵ��һ��hoe
int have_home()
{
	object me = this_object();
	string name = me->query_name();
	if(HOMED->have_home(name))
		return 1;
	return 0;
}*/
