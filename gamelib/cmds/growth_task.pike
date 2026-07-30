#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	string s = "";

	if(!me)
		return 0;
	// 等级门槛可能在进入对应引导步骤前已经满足，打开历练页时补做自动结算。
	NEWBIED->try_auto_complete(me);

	if(arg=="accept"){
		int result = TASKD->accept_growth_task(me);
		if(result==1)
			s += "你领取了本级职业历练。\n\n";
		else if(result==2)
			s += "当前职业尚未开放每级历练。\n\n";
		else if(result==3)
			s += "当前等级无法领取职业历练。\n\n";
		else if(result==4)
			s += "你已经领取了一项职业历练。\n\n";
		else if(result==5)
			s += "你已经完成了本级职业历练。\n\n";
		else
			s += "领取职业历练失败，请稍后重试。\n\n";
		if(result==1 || result==4 || result==5)
			NEWBIED->try_auto_complete(me);
	}
	else if(arg=="cancel"){
		if(TASKD->cancel_growth_task(me))
			s += "你放弃了当前职业历练；重新领取后进度会从零开始。\n\n";
		else
			s += "你当前没有可放弃的职业历练。\n\n";
	}
	else if(arg=="claim"){
		mapping award = TASKD->claim_growth_task(me);
		if(award["code"]==6){
			s += "你完成了"+award["level"]+"级职业历练！\n";
			if(award["exp"]>0)
				s += "得到了"+award["exp"]+"点经验。\n";
			s += "得到了"+
				MUD_MONEYD->query_other_money_cn(award["money"])+"。\n";
			if(award["level_up"])
				s += "你的等级提升到了 "+me->query_level()+" 级！\n";
			s += "\n";
		}
		else if(award["code"]==1)
			s += "你当前没有可提交的职业历练。\n\n";
		else if(award["code"]==2)
			s += "领取历练后职业发生了变化，暂时不能提交。\n\n";
		else if(award["code"]==3)
			s += "本级职业历练尚未完成。\n\n";
		else if(award["code"]==5)
			s += "本级职业历练已经领取过奖励。\n\n";
		else
			s += "提交职业历练失败，请稍后重试。\n\n";
	}

	s += TASKD->queryGrowthTaskPage(me);
	s += "\n[返回任务列表:mytasks]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
