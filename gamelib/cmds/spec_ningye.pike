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
				s += "[一级凝液术:spec_use_ningye 1](耗法200，制造三清水5瓶)\n";
			if(me->query_think() >= 100)
				s += "[二级凝液术:spec_use_ningye 2](耗法400，制造滋生水5瓶)\n";
			if(me->query_think() >= 150)
				s += "[三级凝液术:spec_use_ningye 3](耗法600，制造冰心泉水5瓶)\n";
			if(me->query_think() >= 200)
				s += "[四级凝液术:spec_use_ningye 4](耗法800，制造天山甘露5瓶)\n";
			if(me->query_think() >= 250)
				s += "[五级凝液术:spec_use_ningye 5](耗法1000，制造琼浆液5瓶)\n";
		}
		s += "[返回:myskills]\n";
		s += "[返回游戏:look]\n";
		write(s);
	}
	return 1;
}
