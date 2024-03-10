#include <command.h>
#include <gamelib/include/gamelib.h>
//arg 
//此指令查看特殊熔炼的信息`
int main(string arg)
{
	string s = "";
	object me=this_player();
	if(me->vice_skills["duanzao"] == 0)
		s += "你现在并不会锻造技能\n";
	else{
		s += "特定的装备熔炼将有一定几率获得如下物品：\n";
		s += RONGLIAND->query_spec_desc();
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
