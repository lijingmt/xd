#include <command.h>
#include <gamelib/include/gamelib.h>
//会员折扣商品目录
int main(string|zero arg)
{
	object me = this_player();
	string type = "";
	string lv = "";
	sscanf(arg,"%s %s",type,lv);
	string s = "*** 会员折扣场 ***\n";
	int level;
	sscanf(lv,"%d",level);
	if(level<1 || level>VIP_MAX_LEVEL || !VIPD->get_vip_name(level))
		s +="会员档位无效，请返回重新选择。\n";
	else{
		for(int index=1;index<=VIP_MAX_LEVEL;index++){
			string name=VIPD->get_vip_name(index);
			if(index>1)
				s += "|";
			if(index==level)
				s += name;
			else
				s += "["+name+":vip_myzone_off_list "+type+" "+index+"]";
		}
		s += "\n--------\n";
		s += VIPD->display_off_goods(type,level);
	}
	s += "\n[返回:vip_myzone]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
