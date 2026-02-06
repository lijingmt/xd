#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令列出帮战中可用霸王徽记换取的装备列表
//arg = type
//   type="weapon" , "buyi"，"qingjia" or "zhongkai" "spec"
int main(string arg)
{
	string s = "这里的东西只属于霸者\n";
	object me=this_player();
	string type = arg;
	string map_race = environment(me)->room_race;
		if(type == "weapon"){
			s += "武器|[布衣:bz_view_equiplist buyi]|[轻甲:bz_view_equiplist qingjia]|[重铠:bz_view_equiplist zhongkai]|[特殊:bz_view_equiplist spec]\n";
			s += "[【霸】定魂剑:bz_equip_exchange "+type+" 40dinghunjian 36 100000 0]\n";
			s += "[【霸】定魂匕首:bz_equip_exchange "+type+" 40dinghunbishou 24 50000 0]\n";
			s += "[【霸】镇魂刀:bz_equip_exchange "+type+" 40zhenhundao 48 150000 0]\n";
			s += "[【霸】守护神杖:bz_equip_exchange "+type+" 40shouhushenzhang 48 150000 0]\n";
			s += "----\n";
			s += "[【霸】风啸剑:bz_equip_exchange "+type+" 49fengxiaojian 75 300000 0]\n";
			s += "[【霸】狮鬃匕首:bz_equip_exchange "+type+" 49shizongbishou 50 200000 0]\n";
			s += "[【霸】怒吼刀:bz_equip_exchange "+type+" 49nuhoudao 100 500000 0]\n";
			s += "[【霸】狮王圣杖:bz_equip_exchange "+type+" 49shiwangshengzhang 100 500000 0]\n";
		}
		else if(type == "buyi"){
			s += "[武器:bz_view_equiplist weapon]|布衣|[轻甲:bz_view_equiplist qingjia]|[重铠:bz_view_equiplist zhongkai]|[特殊:bz_view_equiplist spec]\n";
			s += "[【霸】守护布腕:bz_equip_exchange "+type+" 40shouhubuwan 12 50000 0]\n";
			s += "[【霸】守护长裤:bz_equip_exchange "+type+" 40shouhuchangku 18 50000 0]\n";
			s += "[【霸】守护法袍:bz_equip_exchange "+type+" 40shouhufapao 24 50000 0]\n";
			s += "----\n";
			s += "[【霸】狮王布腕:bz_equip_exchange "+type+" 49shiwangbuwan 45 200000 0]\n";
			s += "[【霸】狮王长裤:bz_equip_exchange "+type+" 49shiwangchangku 50 200000 0]\n";
			s += "[【霸】狮王法袍:bz_equip_exchange "+type+" 49shiwangfapao 55 200000 0]\n";
		}
		else if(type == "qingjia"){
			s += "[武器:bz_view_equiplist weapon]|[布衣:bz_view_equiplist buyi]|轻甲|[重铠:bz_view_equiplist zhongkai]|[特殊:bz_view_equiplist spec]\n";
			s += "[【霸】守护皮腕:bz_equip_exchange "+type+" 40shouhupiwan 12 50000 0]\n";
			s += "[【霸】守护皮裤:bz_equip_exchange "+type+" 40shouhupiku 18 50000 0]\n";
			s += "[【霸】守护背甲:bz_equip_exchange "+type+" 40shouhubeijia 24 50000 0]\n";
			s += "----\n";
			s += "[【霸】狮王皮腕:bz_equip_exchange "+type+" 49shiwangpiwan 45 200000 0]\n";
			s += "[【霸】狮王皮裤:bz_equip_exchange "+type+" 49shiwangpiku 50 200000 0]\n";
			s += "[【霸】狮王背甲:bz_equip_exchange "+type+" 49shiwangbeijia 55 200000 0]\n";
		}
		else if(type == "zhongkai"){
			s += "[武器:bz_view_equiplist weapon]|[布衣:bz_view_equiplist buyi]|[轻甲:bz_view_equiplist qingjia]|重铠|[特殊:bz_view_equiplist spec]\n";
			s += "[【霸】守护铁腕:bz_equip_exchange "+type+" 40shouhutiewan 12 50000 0]\n";
			s += "[【霸】守护裤铠:bz_equip_exchange "+type+" 40shouhukukai 18 50000 0]\n";
			s += "[【霸】守护战铠:bz_equip_exchange "+type+" 40shouhuzhankai 24 50000 0]\n";
			s += "----\n";
			s += "[【霸】狮王锁腕:bz_equip_exchange "+type+" 49shiwangsuowan 45 200000 0]\n";
			s += "[【霸】狮王裤铠:bz_equip_exchange "+type+" 49shiwangkukai 50 200000 0]\n";
			s += "[【霸】狮王战铠:bz_equip_exchange "+type+" 49shiwangzhankai 55 200000 0]\n";
		}
		else if(type == "spec"){
			s += "[武器:bz_view_equiplist weapon]|[布衣:bz_view_equiplist buyi]|[轻甲:bz_view_equiplist qingjia]|[重铠:bz_view_equiplist zhongkai]|特殊\n";
			s += "[【霸】火灵酒:bz_equip_exchange "+type+" bz_huolingjiu 4 40000 0]\n";
			s += "[【霸】延寿丹:bz_equip_exchange "+type+" bz_yanshouwan 4 40000 0]\n";
			s += "[【霸】邪羽浆:bz_equip_exchange "+type+" bz_xieyujiang 3 30000 0]\n";
			s += "[【霸】霸仙露:bz_equip_exchange "+type+" bz_baxianlu 3 30000 0]\n";
		}
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
