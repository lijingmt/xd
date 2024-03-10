#include <command.h>
#include <gamelib/include/gamelib.h>
//arg =  
//此指令在玩家熔解物品时最先调用，列出玩家目前能熔解的物品列表
int main(string arg)
{
	string s = "";
	object me=this_player();
	if(me->vice_skills["duanzao"] == 0)
		s += "你现在并不会锻造技能\n";
	else{
		s += "选择你要溶解的物品：\n";
		s += RONGJIED->query_can_rongjie(me);
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "\n[返回游戏:look]\n";
	//write(s);
	return 1;
}
