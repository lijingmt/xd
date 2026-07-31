#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(arg && me->skills_enable == arg && MUD_SKILLSD[arg]){
		me->skills_enable = "";
		me->skills_enable_colddown = 0;
		me["/plus/autofight_skill_mode"] = "off";
		s += "你将技能 "+MUD_SKILLSD[arg]->query_name_cn()+" 取消在战斗中自动施放。\n";
	}
	else
		s += "当前没有这个自动施放技能。\n";
	write(s);
	write("[返回:myskills]\n");
	write("[返回游戏:look]\n");
	//this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
