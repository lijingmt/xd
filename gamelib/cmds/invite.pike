#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object player=this_player();
	string action=lower_case(String.trim_all_whites(arg || "stats"));
	if(!player)
		return 0;
	if(action!="" && action!="stats"){
		write("邀请命令无效。\n[查看邀请统计:invite stats]\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	mapping result=REFERRALD->settle_and_query(player);
	if(!(int)result["ok"]){
		write((string)(result["message"] || "邀请统计暂时不可用")+"\n"+
			"[重试:invite stats]|[返回游戏:look]\n");
		return 1;
	}
	string output="【我的邀请】\n";
	output+="邀请码："+(string)result["inviter_account"]+"\n";
	output+="直属邀请："+(int)result["invite_count"]+"人"+
		"（奖励期内"+(int)result["active_count"]+"人）\n";
	output+="已产生捐赠："+(int)result["donor_count"]+"人\n";
	output+="累计有效捐赠："+(int)result["eligible_recharge_fee"]+
		"元\n";
	output+="累计10%返玉："+
		YUSHID->get_yushi_for_desc((int)result["total_reward"])+"\n";
	if((int)result["settled_now"]>0)
		output+="本次到账："+
			YUSHID->get_yushi_for_desc((int)result["settled_now"])+"\n";
	output+="太古自选卷轴：已达成"+(int)result["scroll_earned"]+
		"张，已发放"+(int)result["scroll_delivered"]+"张\n";
	if((int)result["new_scrolls"]>0)
		output+="本次新发放"+(int)result["new_scrolls"]+
			"张太古传承择卷，请到背包查看。\n";
	output+="距下一张卷轴还差累计有效捐赠"+
		(int)result["next_scroll_remaining"]+"元。\n";
	output+="\n规则：直属账号注册后180天内，每笔真实捐赠返10%仙玉；"+
		"累计每满300元再送1张绑定太古自选卷轴。"+
		"同账号多职业只计一次，重复补单不重复累计。\n";
	if((int)result["pending_count"]>0)
		output+="当前有"+(int)result["pending_count"]+
			"笔奖励尚未安全结算，请稍后重试或联系管理员。\n";
	output+="\n[刷新并领取:invite stats]|[返回游戏:look]\n";
	write(output);
	return 1;
}
