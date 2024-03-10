#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "你的智力将决定技能的等级\n";
	int flag;
	object me=this_player();
	if(!arg){
		me->command("look");
		return 1;
	}
	else if(me->in_combat){
		me->command("attack");
		return 1;
	}
	else{
		sscanf(arg,"%d",flag);
		if(flag == 0){
			s += "技能尚未冷却\n";
		}
		else if(flag == 1){
			if(me->query_think() >= 0)
				s += "[一级化物术:spec_use_huawu 1](耗法200，制造清馨草5颗)\n";
			if(me->query_think() >= 100)
				s += "[二级化物术:spec_use_huawu 2](耗法400，制造龙须根5颗)\n";
			if(me->query_think() >= 150)
				s += "[三级化物术:spec_use_huawu 3](耗法600，制造血叶参5颗)\n";
			if(me->query_think() >= 200)
				s += "[四级化物术:spec_use_huawu 4](耗法800，制造天颜灵芝5颗)\n";
			if(me->query_think() >= 250)
				s += "[五级化物术:spec_use_huawu 5](耗法1000，制造百寿蟠桃5颗)\n";
		}
		s += "[返回:myskills]\n";
		s += "[返回游戏:look]\n";
		write(s);
	}
	return 1;
}
