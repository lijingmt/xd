#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	int level = me->query_level();
	string out = "【新手补给商店】\n\n";

	if(level<=NEWBIED->query_newbie_supply_max_level())
		out += "[领取免费红蓝药:get_free_yao]\n";
	else
		out += "免费红蓝药只向30级及以下人物开放。\n";

	if(level<NEWBIED->query_catchup_exp_min_buy_level()){
		if(NEWBIED->query_starter_exp_potion_granted(me))
			out += "免费二倍追光露：已领取（每个角色一次）。\n";
		else
			out += "[免费领取二倍追光露:catchup_exp_potion claim]\n";
		out += "二倍打怪经验持续30分钟，69级前均可服用。\n";
	}
	else if(level<=NEWBIED->query_catchup_exp_max_level()){
		out += "[购买2倍/3倍/5倍追赶经验药:catchup_exp_potion]\n";
		out += "20～69级使用玉石购买，倍数越高价格越高。\n";
	}
	else{
		out += "你已达到70级，追赶经验药不能再购买或服用。\n";
	}

	out += "\n经验药同类效果不叠加，后服用的会覆盖原效果。\n";
	out += "[新手引导:newbie_guide]|[挂机设置:autofight open]\n";
	out += "[查看道具:inventory_daoju]\n";
	out += "[返回游戏:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,out);
	return 1;
}
