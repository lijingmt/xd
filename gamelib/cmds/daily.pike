#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	string result = "";
	if(!me)
		return 0;
	if(arg=="sign"){
		mapping claim = DAILYGOALD->claim_signin(me);
		result += (string)claim["message"]+"\n";
		if(claim["ok"]){
			result += "获得"+(int)claim["exp"]+"点经验、"+
				MUD_MONEYD->query_other_money_cn((int)claim["money"])+"。\n";
			if(claim["level_up"])
				result += "你的等级提升到了 "+me->query_level()+" 级！\n";
		}
		result += "\n";
	}
	else if(arg && has_prefix(arg,"claim ")){
		int threshold = (int)arg[6..];
		mapping claim = DAILYGOALD->claim_activity_reward(me,threshold);
		result += (string)claim["message"]+"\n";
		if(claim["ok"]){
			result += "获得"+(int)claim["exp"]+"点经验、"+
				MUD_MONEYD->query_other_money_cn((int)claim["money"])+"。\n";
			if(claim["level_up"])
				result += "你的等级提升到了 "+me->query_level()+" 级！\n";
		}
		result += "\n";
	}
	else if(arg && arg!="")
		result += "未知的每日修行操作。\n\n";
	result += DAILYGOALD->query_daily_page(me);
	write(result);
	return 1;
}
