#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = num "skills"  or num "other"
int main(string arg)
{
	int num;
	string flag = "";
	sscanf(arg,"%d %s",num,flag);
	string s = "配置快捷键"+(num+1)+":\n";
	s += "[技能:toolbar_view "+num+" skills]|[药品:toolbar_view "+num+" other]\n";
	if(flag == "skills")
		s += this_player()->view_skills_toolbar(num); //在wapmud2/inherit/feature/skills.pike里定义
	else if(flag == "other")
		s += this_player()->view_things_toolbar(num); //在char.pike定义
	s += "[返回:my_toolbar]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}

