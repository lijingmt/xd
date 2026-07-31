#include <command.h>
#include <gamelib/include/gamelib.h>

private string format_wait_time(int seconds)
{
	int minutes;
	if(seconds < 0)
		seconds = 0;
	minutes = seconds/60;
	if(seconds%60)
		minutes++;
	return minutes+"分钟";
}

int main(string|zero arg)
{
	object me;
	mapping result;
	string out;
	int wait_seconds;
	me = this_player();
	if(!me)
		return 1;
	if(me->in_combat){
		out = "战斗中不能领取补给，请先结束战斗。\n";
		out += "[返回游戏:look]\n";
		write(out);
		return 1;
	}

	result = NEWBIED->claim_newbie_supplies(me);
	out = "【新手免费红蓝药】\n";
	if(result["code"]==1){
		out += "领取成功：新手回春丹×"+result["red"]+
			"，新手凝神露×"+result["blue"]+"。\n";
		out += "自动挂机已优先使用这套补给；红药恢复500生命，蓝药恢复300法力。\n";
		out += "本小时已领取 "+result["used"]+"/"+result["limit"]+" 次。\n";
	}
	else if(result["code"]==2)
		out += "免费新手补给只向30级及以下人物开放。\n";
	else if(result["code"]==3){
		wait_seconds = 3600-time()%3600;
		out += "本小时领取次数已经用完，约"+
			format_wait_time(wait_seconds)+"后刷新。\n";
		out += "当前等级每小时可以领取"+result["limit"]+"次。\n";
	}
	else if(result["code"]==4)
		out += "背包无法接收红蓝药，请先整理背包后重试。\n";
	else
		out += "补给领取失败，请稍后重试。\n";

	out += "\n1—10级每小时3次，11—20级2次，21—30级1次；退出重登不会刷新次数。\n";
	out += "[继续领取:get_free_yao]\n";
	out += "[挂机设置:autofight open]|[查看道具:inventory_daoju]\n";
	out += "[返回游戏:look]\n";
	write(out);
	return 1;
}
