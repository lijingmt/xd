#include <wapmud2.h>
inherit LOW_F_HIDDEN;//传输层转码
inherit MUD_USER;//游戏架构层用户属性
inherit MUD_F_GHOST;//游戏wap层死亡处理
inherit WAP_F_FIGHT;//游戏wap层战斗处理
inherit WAP_F_VIEWSTACK;//游戏wap层视图堆栈
inherit WAP_F_VIEW_LINKS;//游戏wap层超连接方式
inherit WAP_F_VIEW_INVENTORY;//游戏wap层角色，物品显示方式
inherit WAP_F_CATCH_TELL;//游戏wap层信息缓存
inherit WAP_F_VIEW_PICTURE;//游戏wap层图片显示
inherit WAP_F_VIEW_SKILLS;//游戏wap技能表现层
inherit WAP_F_QQLIST;//游戏wap层好友系统
inherit WAP_F_MBOX;//游戏wap层聊天信息系统

string user_mid;
string user_mkey;

string query_UNCONSCIOUS(){
	return unconscious_msg+"[等待:look]\n";
}
string query_LOGIN_MSG(){
	return "登录信息已经过期，请重新进入游戏\n[url 狗go首页:http://dogstart.com]\n[url wap天下:http://tx.com.cn]\n";
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
	s += "［武器］\n";
	string user_equip_main_weapon = me->query_equiped_main_weapons();
	string user_equip_other_weapon = me->query_equiped_other_weapons();
	s += "□主手：";
	if(user_equip_main_weapon&&sizeof(user_equip_main_weapon)){
		s += user_equip_main_weapon;
	}
	else
		s += "\n";
	//////////////////////////
	s += "□副手：";
	if(user_equip_other_weapon&&sizeof(user_equip_other_weapon)){
		s += user_equip_other_weapon;
	}
	else
		s += "\n";
	s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "［防具］\n";
	string user_equip_armor = me->query_equiped_armor();
	if(user_equip_armor&&sizeof(user_equip_armor))
		s += user_equip_armor;
	else
		s += "\n";
	s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "［首饰］\n";
	string user_equip_jewelry = me->query_equiped_jewelry();
	if(user_equip_jewelry&&sizeof(user_equip_jewelry))
		s += user_equip_jewelry;
	else
		s += "\n";
	s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "［饰物］\n";
	string user_equip_decorate = me->query_equiped_decorate();
	if(user_equip_decorate&&sizeof(user_equip_decorate))
		s += user_equip_decorate;
	else
		s += "\n";
	return s;
}
//玩家身上装备的主手武器
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
//玩家身上装备的副手武器
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
//玩家身上装备的防具
string query_equiped_armor(){
	object me = this_object();
	string out="";
	mapping(string:int) name_count=([]);
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_type()=="armor"){
			string ob_name = ob->query_name();
			if(ob->query_item_kind()=="armor_head")
out+="□头部：["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="armor_cloth")
				out+="□胸部：["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="armor_waste")
				out+="□腕部：["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="armor_hand")
				out+="□手部：["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="armor_thou")
				out+="□腿部：["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="armor_shoes")
				out+="□脚部：["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			name_count[ob_name]++;
		}
	}
	return out;
}
//玩家身上装备的首饰
string query_equiped_jewelry(){
	object me = this_object();
	string out="";
	mapping(string:int) name_count=([]);
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_type()=="jewelry"){
			string ob_name = ob->query_name();
			if(ob->query_item_kind()=="jewelry_ring")
				out+="□手指：["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="jewelry_neck")
				out+="□颈部：["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="jewelry_bangle")
				out+="□手腕：["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			name_count[ob_name]++;
		}
	}
	return out;
}
//玩家身上装备的饰物
string query_equiped_decorate(){
	object me = this_object();
	string out="";
	mapping(string:int) name_count=([]);
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_type()=="decorate"){
			string ob_name = ob->query_name();
			if(ob->query_item_kind()=="decorate_manteau")
				out+="□背部：["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="decorate_thing")
				out+="□挂件：["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			if(ob->query_item_kind()=="decorate_tool")
				out+="□饰品：["+ob->query_name_cn()+":inv_other "+me->query_name()+" "+ob_name+" "+name_count[ob_name]+"]\n";
			name_count[ob_name]++;
		}
	}
	return out;
}
/*//得到玩家是否拥有一处hoe
int have_home()
{
	object me = this_object();
	string name = me->query_name();
	if(HOMED->have_home(name))
		return 1;
	return 0;
}*/
