#include <command.h>
#include <gamelib/include/gamelib.h>
/*
会员服务首页
auther: evan
2008.07.16
*/
int main(string|zero arg)
{
	object me = this_player();
	string s = "***会员优惠政策***\n\n";
	s += "0、享受一个月(30天)部分项目免费使用服务\n";
	s += "1、已获得会员资格玩家也可以花费一定玉石进行升级服务\n";
	s += "2、会员期过半之后，申请升级会员,将享受升级价格6折优惠\n";
	s += "3、会员期间续费可以享受9折优惠\n";
	s += "4、普通玩家等级上限为"+NORMAL_MAX_LEVEL+"级；有效VIP每提高一级，上限增加"+VIP_LEVEL_LIMIT_STEP+"级\n   ";
	for(int level=1;level<=VIP_MAX_LEVEL;level++){
		if(level>1)
			s += "、";
		s += VIPD->get_vip_name(level)+
			VIPD->query_vip_level_limit(level)+"级";
	}
	s += "\n";
	s += "   VIP过期或降档不会降低已有等级，但达到当前上限后将停止获得升级经验\n\n";
	s += "5、方士/镇越/天象/灵医职业技能、手动操作和战斗数值永久免费；会员职业助手只提供监控、PVE自动化、策略槽和统计\n";
	s += "   水晶：监控+1槽；黄金：PVE自动执行+2槽；白金：团队协同+3槽；钻石及以上：自适应策略+4槽\n";
	s += "   会员到期后技能、等级、外观及配置全部保留，仅自动执行暂停\n\n";

	s += VIPD->get_level_limit_des(me)+"\n";
	s += VIPD->get_level_limit_action_links(me)+"\n";
	s += VIPD->get_vip_state_des(me);

	s += "\n[返回:vip_service_list.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
