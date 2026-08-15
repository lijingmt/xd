#include <command.h>
#include <gamelib/include/gamelib.h>

/** Render a destination-owned result page after a quick-battle death handoff. */
int main(string|zero arg)
{
	object me=this_player();
	string notice="";
	if(!me)
		return 0;
	if(functionp(me->consume_worker_quick_battle_notice))
		notice=me->consume_worker_quick_battle_notice();
	if(notice=="")
		notice="【快速战斗】战斗已经结束。\n";
	notice+="[返回游戏:look]\n";
	write(notice);
	return 1;
}
