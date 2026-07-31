#include <command.h>
#include <gamelib/include/gamelib.h>
/*
会员升级详细页面
auther: evan
2008.07.18
*/
int main(string|zero arg)
{
	object me = this_player();
	string s = "***会员升级***\n\n";
	int new_level = 0;//升级后的级别
	sscanf(arg,"%d",new_level);
	int state = VIPD->get_vip_state(me);
	int old_level = me->query_vip_flag();//当前级别
	if(!state || old_level<1 || old_level>=VIP_MAX_LEVEL ||
	   new_level<=old_level || new_level>VIP_MAX_LEVEL ||
	   !VIPD->get_vip_name(new_level)){
		write("会员升级目标无效，本次没有扣除玉石。\n"+
			"[返回会员升级:vip_service_upgrade_list]\n");
		return 1;
	}
	string new_vip_desc = VIPD->get_vip_desc(new_level);
	mapping vip_name = VIPD->get_vip_name_map();
	mapping vip_cost = VIPD->get_vip_cost_map();
	string new_desc = VIPD->get_vip_desc(new_level);
	s += vip_name[new_level] + "\n\n";
	s += new_desc+"\n";

	int cost = ((int)vip_cost[new_level]-(int)vip_cost[old_level]);
	if(state==2||state==3)
	{
		cost=cost*6/10;//会员期限过半后，享受6折优惠
	}
	s += "你即将升级为"+vip_name[new_level]+",需要花费"+ YUSHID->get_yushi_for_desc(cost*10)+"\n\n";
	s += "升级后等级上限："+VIPD->query_vip_level_limit(new_level)+"级\n";
	s += "[确认:vip_service_upgrade_confirm.pike "+new_level+"]\n";
	s += "[玉石不足？捐赠获取仙玉:add_szx_fee]\n";
	s += "[返回:vip_service_upgrade_list.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
