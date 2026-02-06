#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令列出帮战中可用圣诞星星换取的装备列表
//arg = type
//   type="weapon" , "shipin"
int main(string arg)
{
	string s = "这里的东西都带着冬天的气息\n";
	object me=this_player();
	string type = arg;
	string map_race = environment(me)->room_race;
	if(type == "weapon"){
		s += "武器|[饰品:bx_view_equiplist shipin]\n";
		s += "[【冰】冰裂刀:bx_equip_exchange "+type+" weapon/29bingliedao 80 300000 0]\n";
		s += "[【冰】冰刺匕首:bx_equip_exchange "+type+" weapon/29bingcibishou  60 300000 0]\n";
		s += "[【冰】冰岩撕裂者:bx_equip_exchange "+type+" weapon/29bingyansiliezhe 120 300000 0]\n";
		s += "[【冰】棂光杖:bx_equip_exchange "+type+" weapon/29lingguangzhang 120 300000 0]\n";
		s += "----\n";
		s += "[【雪】雪月神剑:bx_equip_exchange "+type+" weapon/49xueyueshenjian  160 500000 0]\n";
		s += "[【雪】冰龙之牙:bx_equip_exchange "+type+" weapon/49binglongzhiya 120 500000 0]\n";
		s += "[【雪】万年寒冰斧:bx_equip_exchange "+type+" weapon/49wannianhanbingfu 240 500000 0]\n";
		s += "[【雪】幻雪杖:bx_equip_exchange "+type+" weapon/49huanxuezhang 240 500000 0]\n";
		s += "----\n";
		s += "[【晶】寒冷剑:bx_equip_exchange "+type+" weapon/69hanlengjian 240 700000 0]\n";
		s += "[【晶】寒冰刺:bx_equip_exchange "+type+" weapon/69hanbingci 240 700000 0]\n";
		s += "[【晶】寒冰双剑:bx_equip_exchange "+type+" weapon/69hanbingshuangjian 480 700000 0]\n";
		s += "[【晶】冰月灵杖:bx_equip_exchange "+type+" weapon/69bingyuelingzhang 480 700000 0]\n";
	}
	else if(type == "shipin"){
		s += "[武器:bx_view_equiplist weapon]|饰品\n";
		s += "[【冰】冰泪项链:bx_equip_exchange "+type+" jewelry/29bingleixianglian 60 200000 0]\n";
		s += "[【冰】冰绒披风:bx_equip_exchange "+type+" jewelry/29bingrongpifeng 60 200000 0]\n";
		s += "[【冰】冰龙雕像:bx_equip_exchange "+type+" jewelry/29binglongdiaoxiang 60 200000 0]\n";
		s += "[【冰】冰晶指环:bx_equip_exchange "+type+" jewelry/29bingjingzhihuan 60 200000 0]\n";
		s += "----\n";
		s += "[【雪】霜寒吊坠:bx_equip_exchange "+type+" jewelry/49shuanghandiaozhui 120 400000 0]\n";
		s += "[【雪】雪雾披风:bx_equip_exchange "+type+" jewelry/49xuewupifeng 120 400000 0]\n";
		s += "[【雪】冰雪女神像:bx_equip_exchange "+type+" jewelry/49bingxuenvshenxiang 120 400000 0]\n";
		s += "[【雪】星芒指环:bx_equip_exchange "+type+" jewelry/49xingmangzhihuan 120 400000 0]\n";
		s += "----\n";
		s += "[【晶】寒夜仙戒:bx_equip_exchange "+type+" jewelry/69hanyexianjie 360 600000 0]\n";
		s += "[【晶】寒夜披风:bx_equip_exchange "+type+" jewelry/69hanyepifeng 360 600000 0]\n";
		s += "[【晶】寒飞项链:bx_equip_exchange "+type+" jewelry/69hanfeixianglian 360 600000 0]\n";
		s += "[【晶】寒飞手镯:bx_equip_exchange "+type+" jewelry/69hanfeishouzhuo 360 600000 0]\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
