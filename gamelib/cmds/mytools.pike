#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "［武器装备］\n";
	s += "[［人物属性］:myinfo]\n";
	s += "[［人物状态］:myhp]\n";
	//s += "攻击强度："+me->query_low_attack_desc()+"-"+me->query_high_attack_desc()+"\n";
	////////////////////////////////////////////////////////////////////////////////
	//s += "攻击速度："+me->query_speed_power("main")+"("+me->query_speed_power("other")+")\n";
	////////////////////////////////////////////////////////////////////////////////
	//s += "防御强度："+me->query_defend_power()+"\n";
	////////////////////////////////////////////////////////////////////////////////
	//s += "［武器］\n";
	/*
	string user_equip_main_weapon = me->query_equiped_main_weapons();
	string user_equip_other_weapon = me->query_equiped_other_weapons();
	s += "□主手：";
	if(user_equip_main_weapon&&sizeof(user_equip_main_weapon)){
		s += user_equip_main_weapon;//+"\n";
		s += "伤害："+me->query_low_attack("base_main")+"-"+me->query_high_attack("limit_main")+"\n";
		s += "速度："+me->query_speed_power("main")+"\n";
	}
	else
		s += "无\n";
	//////////////////////////
	s += "□副手：";
	if(user_equip_other_weapon&&sizeof(user_equip_other_weapon)){
		s += user_equip_other_weapon;
		s += "伤害："+me->query_low_attack("base_other")+"-"+me->query_high_attack("limit_other")+"\n";
		s += "速度："+me->query_speed_power("other")+"\n";
	}
	else
		s += "无\n";
	s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "［防具］\n";
	string user_equip_armor = me->query_equiped_armor();
	if(user_equip_armor&&sizeof(user_equip_armor))
		s += user_equip_armor;
	else
		s += "无\n";
	s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "［首饰］\n";
	string user_equip_jewelry = me->query_equiped_jewelry();
	if(user_equip_jewelry&&sizeof(user_equip_jewelry))
		s += user_equip_jewelry;
	else
		s += "无\n";
	s+="--------\n";
	////////////////////////////////////////////////////////////////////////////////
	s += "［饰物］\n";
	string user_equip_decorate = me->query_equiped_decorate();
	if(user_equip_decorate&&sizeof(user_equip_decorate))
		s += user_equip_decorate;
	else
		s += "无\n";
	////////////////////////////////////////////////////////////////////////////////
	*/
	s += me->view_equip();
	//s += "[返回游戏:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//write(s);
	return 1;
}
