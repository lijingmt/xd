#include <command.h>
#include <gamelib/include/gamelib.h>
//会员折扣商品目录
int main(string arg)
{
	object me = this_player();
	string type = "";
	string lv = "";
	sscanf(arg,"%s %s",type,lv);
	string s = "*** 会员折扣场 ***\n";
	switch(lv){
		case "1":
			s += "水晶|[黄金:vip_myzone_off_list "+type+" 2]|[白金:vip_myzone_off_list "+type+" 3]|[钻石:vip_myzone_off_list "+type+" 4]\n";
		s += "--------\n";
		s += VIPD->display_off_goods(type,1);
		break;
		case "2":
			s += "[水晶:vip_myzone_off_list "+type+" 1]|黄金|[白金:vip_myzone_off_list "+type+" 3]|[钻石:vip_myzone_off_list "+type+" 4]\n";
		s += "--------\n";
		s += VIPD->display_off_goods(type,2);
		break;
		case "3":
			s += "[水晶:vip_myzone_off_list "+type+" 1]|[黄金:vip_myzone_off_list "+type+" 2]|白金|[钻石:vip_myzone_off_list "+type+" 4]\n";
		s += "--------\n";
		s += VIPD->display_off_goods(type,3);
		break;
		case "4":
			s += "[水晶:vip_myzone_off_list "+type+" 1]|[黄金:vip_myzone_off_list "+type+" 2]|[白金:vip_myzone_off_list "+type+" 3]|钻石\n";
		s += "--------\n";
		s += VIPD->display_off_goods(type,4);
		break;
		default:
		s +="东西已经被抢购一空了，下次早点来吧\n";
		break;
	}
	s += "\n[返回:vip_myzone]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
