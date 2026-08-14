#include <command.h>
#include <gamelib/include/gamelib.h>
/*
申请入会详情页面
auther: evan
2008.07.16
*/
int main(string|zero arg)
{
	object me = this_player();
	string s = "***会员申请***\n\n";
	int level = 0;
	sscanf(arg,"%d",level);
	if(level<1 || level>VIP_MAX_LEVEL || !VIPD->get_vip_name(level)){
		write("会员等级无效，请重新选择。\n"+
			"[返回会员申请:vip_service_app_list]\n");
		return 1;
	}
	string vip_name = VIPD->get_vip_name(level);
	string vip_desc = VIPD->get_vip_desc(level);
	int vip_cost = VIPD->get_vip_cost(level);
	s += vip_name + "\n\n";
	s += vip_desc + "\n\n";
	s += "开通后等级上限："+VIPD->query_vip_level_limit(level)+"级\n";
	s += "开通后战斗快捷栏："+(6+level)+"格（普通人物6格）\n";
	s += "需要"+ YUSHID->get_yushi_for_desc(vip_cost*10)+"\n"; 
	s += "[申请:vip_service_app_confirm.pike "+level+"]\n\n";
	if(!YUSHID->have_enough_yushi(me,vip_cost*10))
		s += "[玉石不足？捐赠获取仙玉:add_szx_fee]\n";
	s += "[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
