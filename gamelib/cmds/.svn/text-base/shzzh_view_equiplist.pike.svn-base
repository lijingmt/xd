#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令列出帮战中可用霸王徽记换取的装备列表
//arg = type
//   type="weapon" , "buyi"，"qingjia" or "zhongkai" "spec"
int main(string arg)
{
	string s = "国庆限量版饰品，先到先得～\n";
	object me=this_player();
	string type = arg;
	string map_race = environment(me)->room_race;
		if(type == "9ji"){
			s += "9级饰品|[19级饰品:shzzh_view_equiplist 19ji]\n[29级饰品:shzzh_view_equiplist 29ji]|[39级饰品:shzzh_view_equiplist 39ji]\n[49级饰品:shzzh_view_equiplist 49ji]|[59级饰品:shzzh_view_equiplist 59ji]\n[69级饰品:shzzh_view_equiplist 69ji]\n";
			s += "-------\n";
			s += "[幸福扣:shzzh_equip_exchange "+type+" jewelry/9xingfukou 400 shizizhang1 0]\n";
			s += "[幸福手环:shzzh_equip_exchange "+type+" jewelry/9xingfushouhuan 400 shizizhang1 0]\n";
			s += "[幸福颈饰:shzzh_equip_exchange "+type+" jewelry/9xingfujingshi 400 shizizhang1 0]\n";
			s += "[幸福披风:shzzh_equip_exchange "+type+" jewelry/9xingfupifeng 400 shizizhang1 0]\n";
		}
		else if(type == "19ji"){
			s += "[9级饰品:shzzh_view_equiplist 9ji]|19级饰品\n[29级饰品:shzzh_view_equiplist 29ji]|[39级饰品:shzzh_view_equiplist 39ji]\n[49级饰品:shzzh_view_equiplist 49ji]|[59级饰品:shzzh_view_equiplist 59ji]\n[69级饰品:shzzh_view_equiplist 69ji]\n";
			s += "-------\n";
			s += "[吉祥扣:shzzh_equip_exchange "+type+" jewelry/19jixiangkou 340 shizizhang2 0]\n";
			s += "[吉祥手环:shzzh_equip_exchange "+type+" jewelry/19jixiangshouhuan 340 shizizhang2 0]\n";
			s += "[吉祥颈饰:shzzh_equip_exchange "+type+" jewelry/19jixiangjingshi 340 shizizhang2 0]\n";
			s += "[吉祥披风:shzzh_equip_exchange "+type+" jewelry/19jixiangpifeng 340 shizizhang2 0]\n";
		}
		else if(type == "29ji"){
			s += "[9级饰品:shzzh_view_equiplist 9ji]|[19级饰品:shzzh_view_equiplist 19ji]\n29级饰品|[39级饰品:shzzh_view_equiplist 39ji]\n[49级饰品:shzzh_view_equiplist 49ji]|[59级饰品:shzzh_view_equiplist 59ji]\n[69级饰品:shzzh_view_equiplist 69ji]\n";
			s += "-------\n";
			s += "[如意扣:shzzh_equip_exchange "+type+" jewelry/29ruyikou 280 shizizhang3 0]\n";
			s += "[如意手环:shzzh_equip_exchange "+type+" jewelry/29ruyishouhuan 280 shizizhang3 0]\n";
			s += "[如意颈饰:shzzh_equip_exchange "+type+" jewelry/29ruyijingshi 280 shizizhang3 0]\n";
			s += "[如意披风:shzzh_equip_exchange "+type+" jewelry/29ruyipifeng 280 shizizhang3 0]\n";
		}
		else if(type == "39ji"){
			s += "[9级饰品:shzzh_view_equiplist 9ji]|[19级饰品:shzzh_view_equiplist 19ji]\n[29级饰品:shzzh_view_equiplist 29ji]|39级饰品\n[49级饰品:shzzh_view_equiplist 49ji]|[59级饰品:shzzh_view_equiplist 59ji]\n[69级饰品:shzzh_view_equiplist 69ji]\n";
			s += "-------\n";
			s += "[团圆扣:shzzh_equip_exchange "+type+" jewelry/39tuanyuankou 240 shizizhang4 0]\n";
			s += "[团圆手环:shzzh_equip_exchange "+type+" jewelry/39tuanyuanshouhuan 240 shizizhang4 0]\n";
			s += "[团圆颈饰:shzzh_equip_exchange "+type+" jewelry/39tuanyuanjingshi 240 shizizhang4 0]\n";
			s += "[团圆披风:shzzh_equip_exchange "+type+" jewelry/39tuanyuanpifeng 240 shizizhang4 0]\n";
		}
		else if(type == "49ji"){
			s += "[9级饰品:shzzh_view_equiplist 9ji]|[19级饰品:shzzh_view_equiplist 19ji]\n[29级饰品:shzzh_view_equiplist 29ji]|[39级饰品:shzzh_view_equiplist 39ji]\n49级饰品|[59级饰品:shzzh_view_equiplist 59ji]\n[69级饰品:shzzh_view_equiplist 69ji]\n";
			s += "-------\n";
			s += "[热情扣:shzzh_equip_exchange "+type+" jewelry/49reqingkou 180 shizizhang5 0]\n";
			s += "[热情手环:shzzh_equip_exchange "+type+" jewelry/49reqingshouhuan 180 shizizhang5 0]\n";
			s += "[热情颈饰:shzzh_equip_exchange "+type+" jewelry/49reqingjingshi 180 shizizhang5 0]\n";
			s += "[热情披风:shzzh_equip_exchange "+type+" jewelry/49reqingpifeng 180 shizizhang5 0]\n";
		}
		else if(type == "59ji"){
			s += "[9级饰品:shzzh_view_equiplist 9ji]|[19级饰品:shzzh_view_equiplist 19ji]\n[29级饰品:shzzh_view_equiplist 29ji]|[39级饰品:shzzh_view_equiplist 39ji]\n[49级饰品:shzzh_view_equiplist 49ji]|59级饰品\n[69级饰品:shzzh_view_equiplist 69ji]\n";
			s += "-------\n";
			s += "[和美扣:shzzh_equip_exchange "+type+" jewelry/59hemeikou 100 shizizhang6 0]\n";
			s += "[和美手环:shzzh_equip_exchange "+type+" jewelry/59hemeishouhuan 100 shizizhang6 0]\n";
			s += "[和美颈饰:shzzh_equip_exchange "+type+" jewelry/59hemeijingshi 100 shizizhang6 0]\n";
			s += "[和美披风:shzzh_equip_exchange "+type+" jewelry/59hemeipifeng 100 shizizhang6 0]\n";
		}
		else if(type == "69ji"){
			s += "[9级饰品:shzzh_view_equiplist 9ji]|[19级饰品:shzzh_view_equiplist 19ji]\n[29级饰品:shzzh_view_equiplist 29ji]|[39级饰品:shzzh_view_equiplist 39ji]\n[49级饰品:shzzh_view_equiplist 49ji]|[59级饰品:shzzh_view_equiplist 59ji]\n69级饰品\n";
			s += "-------\n";
			s += "[祥云扣:shzzh_equip_exchange "+type+" jewelry/69xiangyunkou 60 shizizhang7 0]\n";
			s += "[祥云手环:shzzh_equip_exchange "+type+" jewelry/69xiangyunshouhuan 60 shizizhang7 0]\n";
			s += "[祥云颈饰:shzzh_equip_exchange "+type+" jewelry/69xiangyunjingshi 60 shizizhang7 0]\n";
			s += "[祥云披风:shzzh_equip_exchange "+type+" jewelry/69xiangyunpifeng 60 shizizhang7 0]\n";
		}
	s += "\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
