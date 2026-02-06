#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = type
//   type="weapon" , "buyi"，"qingjia" or "zhongkai" "spec"
int main(string arg)
{
	string s = "";
	object me=this_player();
	string type = arg;
	string map_race = environment(me)->room_race;
	if(me->query_raceId() != map_race)
		s += "哪里跑来的妖孽，如此猖狂~~\n";
	else{
		if(me->query_raceId() == "human"){
			if(type == "weapon"){
				s += "武器|[布衣:honer_equip_view buyi]|[轻甲:honer_equip_view qingjia]|[重铠:honer_equip_view zhongkai]|[饰品:honer_equip_view decorate]|[特殊:honer_equip_view spec]\n";
				s += "[【仙】屠魔剑:honer_buy "+type+" 29tumojian bingfusuipian 0 0]\n";
				s += "[【仙】封魔匕首:honer_buy "+type+" 29fengmobishou bingfusuipian 0 0]\n";
				s += "[【仙】浩然长剑:honer_buy "+type+" 29haoranchangjian bingfusuipian 0 0]\n";
				s += "[【仙】灭魔长杖:honer_buy "+type+" 29miemochangzhang bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[【仙】冰破寒光剑:honer_buy "+type+" 49bingpohanguangjian bingfusuipian 0 0]\n";
				s += "[【仙】锦丝匕首:honer_buy "+type+" 49jinsibishou bingfusuipian 0 0]\n";
				s += "[【仙】乾坤神斧:honer_buy "+type+" 49qiankunshenfu bingfusuipian 0 0]\n";
				s += "[【仙】穿云仙杖:honer_buy "+type+" 49chuanyunxianzhang bingfusuipian 0 0]\n";
			}
			else if(type == "buyi"){
				s += "[武器:honer_equip_view weapon]|布衣|[轻甲:honer_equip_view qingjia]|[重铠:honer_equip_view zhongkai]|[饰品:honer_equip_view decorate]|[特殊:honer_equip_view spec]\n";
				s += "[【仙】仙缘布腕:honer_buy "+type+" 30xianyuanbuwan bingfusuipian 0 0]\n";
				s += "[【仙】仙缘护手:honer_buy "+type+" 30xianyuanhushou bingfusuipian 0 0]\n";
				s += "[【仙】仙缘布履:honer_buy "+type+" 30xianyuanbulv bingfusuipian 0 0]\n";
				s += "[【仙】仙缘羽饰:honer_buy "+type+" 30xianyuanyushi bingfusuipian 0 0]\n";
				s += "[【仙】仙缘长裤:honer_buy "+type+" 30xianyuanchangku bingfusuipian 0 0]\n";
				s += "[【仙】仙缘法袍:honer_buy "+type+" 30xianyuanfapao bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[【仙】仙凝布腕:honer_buy "+type+" 49xianningbuwan bingfusuipian 0 0]\n";
				s += "[【仙】仙凝护手:honer_buy "+type+" 49xianninghushuou bingfusuipian 0 0]\n";
				s += "[【仙】仙凝布履:honer_buy "+type+" 49xianningbulv bingfusuipian 0 0]\n";
				s += "[【仙】仙凝羽饰:honer_buy "+type+" 49xianningyushi bingfusuipian 0 0]\n";
				s += "[【仙】仙凝长裤:honer_buy "+type+" 49xianningchangku bingfusuipian 0 0]\n";
				s += "[【仙】仙凝法袍:honer_buy "+type+" 49xianningfapao bingfusuipian 0 0]\n";
			}
			else if(type == "qingjia"){
				s += "[武器:honer_equip_view weapon]|[布衣:honer_equip_view buyi]|轻甲|[重铠:honer_equip_view zhongkai]|[饰品:honer_equip_view decorate]|[特殊:honer_equip_view spec]\n";
				s += "[【仙】仙缘皮腕:honer_buy "+type+" 30xianyuanpiwan bingfusuipian 0 0]\n";
				s += "[【仙】仙缘手套:honer_buy "+type+" 30xianyuanshoutao bingfusuipian 0 0]\n";
				s += "[【仙】仙缘皮靴:honer_buy "+type+" 30xianyuanpixue bingfusuipian 0 0]\n";
				s += "[【仙】仙缘头巾:honer_buy "+type+" 30xianyuantoujin bingfusuipian 0 0]\n";
				s += "[【仙】仙缘皮裤:honer_buy "+type+" 30xianyuanpiku bingfusuipian 0 0]\n";
				s += "[【仙】仙缘外套:honer_buy "+type+" 30xianyuanwaitao bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[【仙】仙凝皮腕:honer_buy "+type+" 49xianningpiwan bingfusuipian 0 0]\n";
				s += "[【仙】仙凝手套:honer_buy "+type+" 49xianningshoutao bingfusuipian 0 0]\n";
				s += "[【仙】仙凝皮靴:honer_buy "+type+" 49xianningpixue bingfusuipian 0 0]\n";
				s += "[【仙】仙凝头巾:honer_buy "+type+" 49xianningtoujin bingfusuipian 0 0]\n";
				s += "[【仙】仙凝皮裤:honer_buy "+type+" 49xianningpiku bingfusuipian 0 0]\n";
				s += "[【仙】仙凝外套:honer_buy "+type+" 49xianningwaitao bingfusuipian 0 0]\n";
			}
			else if(type == "zhongkai"){
				s += "[武器:honer_equip_view weapon]|[布衣:honer_equip_view buyi]|[轻甲:honer_equip_view qingjia]|重铠|[饰品:honer_equip_view decorate]|[特殊:honer_equip_view spec]\n";
				s += "[【仙】仙缘铁腕:honer_buy "+type+" 30xianyuantiewan bingfusuipian 0 0]\n";
				s += "[【仙】仙缘铁爪:honer_buy "+type+" 30xianyuantiezhua bingfusuipian 0 0]\n";
				s += "[【仙】仙缘战靴:honer_buy "+type+" 30xianyuanzhanxue bingfusuipian 0 0]\n";
				s += "[【仙】仙缘面具:honer_buy "+type+" 30xianyuanmianju bingfusuipian 0 0]\n";
				s += "[【仙】仙缘裤铠:honer_buy "+type+" 30xianyuankukai bingfusuipian 0 0]\n";
				s += "[【仙】仙缘战铠:honer_buy "+type+" 30xianyuanzhankai bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[【仙】仙凝铁腕:honer_buy "+type+" 49xianningtiewan bingfusuipian 0 0]\n";
				s += "[【仙】仙凝铁爪:honer_buy "+type+" 49xianningtiezhua bingfusuipian 0 0]\n";
				s += "[【仙】仙凝战靴:honer_buy "+type+" 49xianningzhanxue bingfusuipian 0 0]\n";
				s += "[【仙】仙凝面具:honer_buy "+type+" 49xianningmianju bingfusuipian 0 0]\n";
				s += "[【仙】仙凝裤铠:honer_buy "+type+" 49xianningkukai bingfusuipian 0 0]\n";
				s += "[【仙】仙凝战铠:honer_buy "+type+" 49xianningzhankai bingfusuipian 0 0]\n";
			}
			else if(type == "spec"){
				s += "[武器:honer_equip_view weapon]|[布衣:honer_equip_view buyi]|[轻甲:honer_equip_view qingjia]|[重铠:honer_equip_view zhongkai]|[饰品:honer_equip_view decorate]|特殊\n";
			}
			else if(type == "decorate"){
				s += "[武器:honer_equip_view weapon]|[布衣:honer_equip_view buyi]|[轻甲:honer_equip_view qingjia]|[重铠:honer_equip_view zhongkai]|饰品|[特殊:honer_equip_view spec]\n";
			}
		}
		else if(me->query_raceId() == "monst"){
			if(type == "weapon"){
				s += "武器|[布衣:honer_equip_view buyi]|[轻甲:honer_equip_view qingjia]|[重铠:honer_equip_view zhongkai]|[饰品:honer_equip_view decorate]|[特殊:honer_equip_view spec]\n";
				s += "[【妖】鬼龙剑:honer_buy "+type+" 29guilongjian bingfusuipian 0 0]\n";
				s += "[【妖】邪龙匕首:honer_buy "+type+" 29xielongbishou bingfusuipian 0 0]\n";
				s += "[【妖】魔龙战剑:honer_buy "+type+" 29molongzhanjian bingfusuipian 0 0]\n";
				s += "[【妖】冥火法杖:honer_buy "+type+" 29minghuofazhang bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[【妖】弑天剑:honer_buy "+type+" 49shitianjian bingfusuipian 0 0]\n";
				s += "[【妖】锦缎匕首:honer_buy "+type+" 49jinduanbishou bingfusuipian 0 0]\n";
				s += "[【妖】寒星冷月刀:honer_buy "+type+" 49hanxinglengyuedao bingfusuipian 0 0]\n";
				s += "[【妖】顿水妖杵:honer_buy "+type+" 49dunshuiyaochu bingfusuipian 0 0]\n";
			}
			else if(type == "buyi"){
				s += "[武器:honer_equip_view weapon]|布衣|[轻甲:honer_equip_view qingjia]|[重铠:honer_equip_view zhongkai]|[饰品:honer_equip_view decorate]|[特殊:honer_equip_view spec]\n";
				s += "[【妖】妖冥布腕:honer_buy "+type+" 30yaomingbuwan bingfusuipian 0 0]\n";
				s += "[【妖】妖冥护手:honer_buy "+type+" 30yaominghushou bingfusuipian 0 0]\n";
				s += "[【妖】妖冥布履:honer_buy "+type+" 30yaomingbulv bingfusuipian 0 0]\n";
				s += "[【妖】妖冥羽饰:honer_buy "+type+" 30yaomingyushi bingfusuipian 0 0]\n";
				s += "[【妖】妖冥长裤:honer_buy "+type+" 30yaomingchangku bingfusuipian 0 0]\n";
				s += "[【妖】妖冥法袍:honer_buy "+type+" 30yaomingfapao bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[【妖】妖羽布腕:honer_buy "+type+" 49yaoyubuwan bingfusuipian 0 0]\n";
				s += "[【妖】妖羽护手:honer_buy "+type+" 49yaoyuhushou bingfusuipian 0 0]\n";
				s += "[【妖】妖羽布履:honer_buy "+type+" 49yaoyubulv bingfusuipian 0 0]\n";
				s += "[【妖】妖羽头饰:honer_buy "+type+" 49yaoyutoushi bingfusuipian 0 0]\n";
				s += "[【妖】妖羽长裤:honer_buy "+type+" 49yaoyuchangku bingfusuipian 0 0]\n";
				s += "[【妖】妖羽法袍:honer_buy "+type+" 49yaoyufapao bingfusuipian 0 0]\n";
			}
			else if(type == "qingjia"){
				s += "[武器:honer_equip_view weapon]|[布衣:honer_equip_view buyi]|轻甲|[重铠:honer_equip_view zhongkai]|[饰品:honer_equip_view decorate]|[特殊:honer_equip_view spec]\n";
				s += "[【妖】妖冥皮腕:honer_buy "+type+" 30yaomingpiwan bingfusuipian 0 0]\n";
				s += "[【妖】妖冥手套:honer_buy "+type+" 30yaomingshoutao bingfusuipian 0 0]\n";
				s += "[【妖】妖冥皮靴:honer_buy "+type+" 30yaomingpixue bingfusuipian 0 0]\n";
				s += "[【妖】妖冥头巾:honer_buy "+type+" 30yaomingtoujin bingfusuipian 0 0]\n";
				s += "[【妖】妖冥皮裤:honer_buy "+type+" 30yaomingpiku bingfusuipian 0 0]\n";
				s += "[【妖】妖冥外套:honer_buy "+type+" 30yaomingwaitao bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[【妖】妖羽皮腕:honer_buy "+type+" 49yaoyupiwan bingfusuipian 0 0]\n";
				s += "[【妖】妖羽手套:honer_buy "+type+" 49yaoyushoutao bingfusuipian 0 0]\n";
				s += "[【妖】妖羽皮靴:honer_buy "+type+" 49yaoyupixue bingfusuipian 0 0]\n";
				s += "[【妖】妖羽头巾:honer_buy "+type+" 49yaoyutoujin bingfusuipian 0 0]\n";
				s += "[【妖】妖羽皮裤:honer_buy "+type+" 49yaoyupiku bingfusuipian 0 0]\n";
				s += "[【妖】妖羽外套:honer_buy "+type+" 49yaoyuwaitao bingfusuipian 0 0]\n";
			}
			else if(type == "zhongkai"){
				s += "[武器:honer_equip_view weapon]|[布衣:honer_equip_view buyi]|[轻甲:honer_equip_view qingjia]|重铠|[饰品:honer_equip_view decorate]|[特殊:honer_equip_view spec]\n";
				s += "[【妖】妖冥铁腕:honer_buy "+type+" 30yaomingtiewan bingfusuipian 0 0]\n";
				s += "[【妖】妖冥铁爪:honer_buy "+type+" 30yaomingtiezhua bingfusuipian 0 0]\n";
				s += "[【妖】妖冥战靴:honer_buy "+type+" 30yaomingzhanxue bingfusuipian 0 0]\n";
				s += "[【妖】妖冥面具:honer_buy "+type+" 30yaomingmianju bingfusuipian 0 0]\n";
				s += "[【妖】妖冥裤铠:honer_buy "+type+" 30yaomingkukai bingfusuipian 0 0]\n";
				s += "[【妖】妖冥战铠:honer_buy "+type+" 30yaomingzhankai bingfusuipian 0 0]\n";
				s += "----\n";
				s += "[【妖】妖羽铁腕:honer_buy "+type+" 49yaoyutiewan bingfusuipian 0 0]\n";
				s += "[【妖】妖羽铁爪:honer_buy "+type+" 49yaoyutiezhua bingfusuipian 0 0]\n";
				s += "[【妖】妖羽战靴:honer_buy "+type+" 49yaoyuzhanxue bingfusuipian 0 0]\n";
				s += "[【妖】妖羽面具:honer_buy "+type+" 49yaoyumianju bingfusuipian 0 0]\n";
				s += "[【妖】妖羽裤铠:honer_buy "+type+" 49yaoyukukai bingfusuipian 0 0]\n";
				s += "[【妖】妖羽战铠:honer_buy "+type+" 49yaoyuzhankai bingfusuipian 0 0]\n";
			}
			else if(type == "spec"){
				s += "[武器:honer_equip_view weapon]|[布衣:honer_equip_view buyi]|[轻甲:honer_equip_view qingjia]|[重铠:honer_equip_view zhongkai]|[饰品:honer_equip_view decorate]|特殊\n";
			}
			else if(type == "decorate"){
				s += "[武器:honer_equip_view weapon]|[布衣:honer_equip_view buyi]|[轻甲:honer_equip_view qingjia]|[重铠:honer_equip_view zhongkai]|饰品|[特殊:honer_equip_view spec]\n";
			}
		}
		s += "----\n";
		s += ITEMS_EXCHANGED->query_equip_list(me->query_raceId(),type,"honer_buy");
	}
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
