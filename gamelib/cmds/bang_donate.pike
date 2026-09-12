#include <command.h>
#include <gamelib/include/gamelib.h>
// 帮派建设：捐献银两换建设度与帮贡。
// arg = 金额 或 "0"（查看页面）
int main(string|zero arg)
{
	object me = this_player();
	mapping summary;
	mapping result;
	int amount = 0;
	string s;
	if(!me)
		return 0;
	if(!me->bangid){
		write("你还没有加入帮派，无法参与帮派建设。\n[返回游戏:look]\n");
		return 1;
	}
	if(!BANGD->bang_allows_user(me->bangid,me->query_name())){
		write("该帮派属于其他逻辑区，当前隔离期间不可访问。\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	if(me->query_in_combat()){
		write("交战中不能捐献，请脱离战斗后再试。\n[返回战斗:flushview]\n");
		return 1;
	}
	if(!arg || sscanf(arg,"%d",amount)!=1)
		amount = 0;
	summary = BANGPAI_EXTD->query_gang_summary(me);
	if(!summary){
		write("帮派建设状态暂不可用，请稍后再试。\n[返回游戏:look]\n");
		return 1;
	}
	s = "§g帮派建设§r（"+BANGD->query_bang_name(me->bangid)+"）\n";
	s += "帮派等级："+(string)(int)summary["level"]+"级　"+
		"建设度："+format_game_number((int)summary["exp"])+
		((int)summary["next_cost"]>0 ?
		"／下一级 "+format_game_number((int)summary["next_cost"]) :
		"（已满级）")+"\n";
	s += "我的帮贡："+format_game_number((int)summary["my_contrib"])+
		"　身上银两："+MUD_MONEYD->query_other_money_cn(
		me->query_account())+"\n";
	s += "当前解锁：打怪经验加成"+
		BANGPAI_EXTD->query_gang_exp_bonus_percent(me)+"%"+
		((int)summary["boss_attempts"]>1 ?
		"，帮派BOSS每日"+(string)(int)summary["boss_attempts"]+"次" : "")+
		((int)summary["shop_unlocked"] ? "，帮贡商店" : "")+
		((int)summary["illusion_unlocked"] ? "，帮派幻境" : "")+"\n";
	s += "等级权益：2级经验+2%，3级帮贡商店，4级帮派幻境，"+
		"5级经验+5%，7级BOSS每日2次，8级经验+8%。\n";
	s += "捐献规则：每1000银两=1点建设度+1帮贡；每日捐献帮贡上限500；"+
		"银两不退还。\n";
	if(amount>0){
		result = BANGPAI_EXTD->donate(me,amount);
		if(!(int)result["ok"]){
			write((string)result["message"]+"\n"+
				"[返回帮派建设:bang_donate]\n");
			return 1;
		}
		s += "\n§y捐献成功§r："+
			MUD_MONEYD->query_other_money_cn(amount)+
			"转化为建设度，获得帮贡 "+
			(string)(int)result["gained_contrib"]+" 点。\n";
		if((int)result["leveled"])
			s += "§F帮派升级！当前 "+
				(string)(int)result["level"]+" 级。§r\n";
		summary = BANGPAI_EXTD->query_gang_summary(me);
		s += "帮派等级："+(string)(int)summary["level"]+"级　"+
			"建设度："+format_game_number((int)summary["exp"])+
			((int)summary["next_cost"]>0 ?
			"／下一级 "+format_game_number(
				(int)summary["next_cost"]) : "（已满级）")+
			"　我的帮贡："+
			format_game_number((int)summary["my_contrib"])+"\n";
	}
	s += "[捐献1万:bang_donate 10000]|[捐献10万:bang_donate 100000]|"+
		"[捐献100万:bang_donate 1000000]\n";
	s += "[submit 自定义金额:bang_donate ...]\n";
	s += "[我的帮派:my_bang]|[返回游戏:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
