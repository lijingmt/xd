#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit LOW_F_HIDDEN;
inherit MUD_NPC;
inherit MUD_F_GHOST;//游戏wap层死亡处理
inherit WAP_F_VIEWSTACK;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_INVENTORY;
inherit WAP_F_VIEW_PICTURE;
inherit WAP_F_VIEW_SKILLS;//游戏wap技能表现层
inherit WAP_F_FIGHT;

array(string) query_command_prefix(){
		return ({SROOT+"/wapmud2/cmds/"})+({COMMAND_PREFIX});
}

//boss技能系统 第一次释放时间/冷却时间:技能名字
mapping(string:string) boss_skills = ([]);


void create(){
	//其他主要属性
	life = 10;//生命
	life_max = 10;//生命上限
	mofa = 10;//法力
	mofa_max = 10;//法力上限
	_str = 1;//力量
	_dex = 1;//敏捷
	_think = 1;//智力
	_lunck = 1;//幸运
	_appear = 20;//容貌
	//其他附加属性
	_npcLevel = 1;//默认为一级
	_levelup = 0;//默认为不能自动升级
	_meritocrat = 0;//默认为非精英怪
	_boss = 0;//默认为非boss等级怪
	_rare = 0;//默认为非稀有怪
	_domestication = 0;//默认为不可驯服
	_autolevel = 0;//默认为不可自动调整等级
	_tasknpc = 0;//默认为非任务npc
	_killauto = 0;//默认为非自动攻击类型Npc
	_skillsable = 0;//默认为没有技能
	_troth = 0;//默认为忠诚度为0
	_randomwords = "什么事情\n";//随机话语
	_equiped = 1;//默认可以装备物品
	_flushtime = 5*60;//默认5分钟刷新一次
	_hate = 0;//默认仇恨值为空
	_fury = 0;//狂暴几率为零
	_recovery = 20;//默认回血回蓝系数
}
string query_links(void|int count){
	string kill ="";
	//if(this_object()->is_item())
	//	kill += "[搜身:frisk "+this_object()->name+" "+count+"]\n[杀戮:kill "+this_object()->name+" "+count+"]\n";
	return kill+::query_links();
}
//这里返回的是npc兑换选择连接被点击后返回的随机话语，_randomwords可以返回写好的
//npc的一句话，或者写个deamons，将该npc的阵营，种族，性别，年纪传过去，得到一个
//随机的有意思的对话内容，也是很不错的。
string query_words(){
	//根据怪物职业不同返回不同的随机话语
	string rst = "";
	if(this_object()->query_raceId()=="human"&&this_object()->query_profeId()=="humanlike"){
		rst += "你有什么事情？\n";
	}
	else if(this_object()->query_raceId()=="monst"&&this_object()->query_profeId()=="humanlike"){
		rst += "你有什么事情？\n";
	}
	else if(this_object()->query_profeId()=="humanlike"){
		rst += "别来烦我！\n";
	}
	else if(this_object()->query_profeId()=="beast"){
		rst += "嗷嗷~~~\n";
		rst += "看来它不知道你在说些什么。。。。。\n";
	}
	else if(this_object()->query_profeId()=="bird"){
		rst += "吱吱~~~\n";
		rst += "看来它不知道你在说些什么。。。。。\n";
	}
	else if(this_object()->query_profeId()=="fish"){
		rst += "......\n";
		rst += "看来它不知道你在说些什么。。。。。\n";
	}
	else if(this_object()->query_profeId()=="bugs"){
		rst += "嘶嘶~~~\n";
		rst += "看来它不知道你在说些什么。。。。。\n";
	}
	else if(this_object()->query_profeId()=="amphibian"){
		rst += "嘶嘶~~~\n";
		rst += "看来它不知道你在说些什么。。。。。\n";
	}
	return rst;
}
string view_equip(){
	object me = this_object();
	string s = "";
	//s += "［武器］\n";
	string user_equip_main_weapon = me->query_equiped_main_weapons();
	string user_equip_other_weapon = me->query_equiped_other_weapons();
	//s += "□主手：";
	if(user_equip_main_weapon&&sizeof(user_equip_main_weapon)){
		s += "□主手：";
		s += user_equip_main_weapon;//+"\n";
	}
	if(user_equip_other_weapon&&sizeof(user_equip_other_weapon)){
		s += "□副手：";
		s += user_equip_other_weapon;
	}
	string user_equip_armor = me->query_equiped_armor();
	if(user_equip_armor&&sizeof(user_equip_armor)){
		s += "［防具］\n";
		s += user_equip_armor+"\n";
	}
	//else
	//	s += "\n";
	//s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	//s += "［首饰］\n";
	string user_equip_jewelry = me->query_equiped_jewelry();
	if(user_equip_jewelry&&sizeof(user_equip_jewelry)){
		s += "［首饰］\n";
		s += user_equip_jewelry+"\n";
	}
	//else
	//	s += "\n";
	//s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	//s += "［饰物］\n";
	string user_equip_decorate = me->query_equiped_decorate();
	if(user_equip_decorate&&sizeof(user_equip_decorate)){
		s += "［饰物］\n";
		s += user_equip_decorate+"\n";
	}
	//else
	//	s += "\n";
	return s;
}

//身上装备的主手武器
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
//身上装备的副手武器
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
//身上装备的防具
string query_equiped_armor(){
	string out="";
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_type()=="armor"){
			string s_file = file_name(ob);
			if(ob->query_item_kind()=="armor_head")
				out+="□头部：["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
			if(ob->query_item_kind()=="armor_cloth")
				out+="□胸部：["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
			if(ob->query_item_kind()=="armor_waste")
				out+="□腕部：["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
			if(ob->query_item_kind()=="armor_hand")
				out+="□手部：["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
			if(ob->query_item_kind()=="armor_thou")
				out+="□腿部：["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
			if(ob->query_item_kind()=="armor_shoes")
				out+="□脚部：["+ob->query_name_cn()+":inv_other "+s_file+"]\n";
		}
	}
	return out;
}

//身上装备的首饰
string query_equiped_jewelry(){
	string out="";
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_type()=="jewelry"){
			if(ob->query_item_kind()=="jewelry_ring")
				out+="□手指："+ob->query_name_cn()+"\n";
			if(ob->query_item_kind()=="jewelry_neck")
				out+="□颈部："+ob->query_name_cn()+"\n";
			if(ob->query_item_kind()=="jewelry_bangle")
				out+="□手腕："+ob->query_name_cn()+"\n";
		}
	}
	return out;
}
//身上装备的饰物
string query_equiped_decorate(){
	string out="";
	array(object) items =all_inventory(this_object());
	foreach(items,object ob){
		if(ob["equiped"]&&ob->query_item_type()=="decorate"){
			if(ob->query_item_kind()=="decorate_manteau")
				out+="□背部："+ob->query_name_cn()+"\n";
			if(ob->query_item_kind()=="decorate_thing")
				out+="□挂件："+ob->query_name_cn()+"\n";
			if(ob->query_item_kind()=="decorate_tool")
				out+="□饰品："+ob->query_name_cn()+"\n";
		}
	}
	return out;
}
string query_npc_status(int player_level){
	string s = "";
	/*
	if(this_object()->_meritocrat)
		s += "(精英)\n";
	if(this_object()->_boss)
		s += "(领袖)\n";
	*/
	if(player_level<=0)
		return s + "生命：？\n法力：？";
	else{
		int diff = this_object()->query_level()-player_level; 
		if(diff>=5)
			return s + "生命：？\n法力：？";
		else
			return s + "生命："+this_object()->get_cur_life()+"\n法力："+this_object()->get_cur_mofa();
	}
	return s += "生命：？\n法力：？";
}
/*
string query_dog_attr()
{
	object room = environment(this_object());
	string s = "";
	string st = room->query_dog();
	if(st!=""&&(st/",")[0]=="1"){
		array(string) tmp = st/",";
		//s += "生命："+(int)tmp[2]+"\n力量："+(int)tmp[3]+"\n智力："+(int)tmp[4]+"\n敏捷："+(int)tmp[5];
		s += "力量："+(int)tmp[3]+"\n智力："+(int)tmp[4]+"\n敏捷："+(int)tmp[5];
	}
	return s;
}
*/
