#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(arg && me->skills && me->skills[arg] && MUD_SKILLSD[arg] &&
	   MUD_SKILLSD[arg]->s_type == "zhudong"){
		me->skills_enable = arg;
		me["/plus/autofight_skill_mode"] = "manual";
		s += "你将技能 "+MUD_SKILLSD[arg]->query_name_cn()+" 设置为战斗中自动施放的技能。\n";
	}
	else
		s += "只能把自己已学会的主动技能设置为自动施放技能。\n";
	//this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	write(s);
	write("[返回:myskills]\n");
	write("[返回游戏:look]\n");
	return 1;
}
