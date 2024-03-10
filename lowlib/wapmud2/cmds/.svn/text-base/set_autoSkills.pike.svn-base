#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(arg){
		me->skills_enable = arg;
		s += "你将技能 "+MUD_SKILLSD[arg]->query_name_cn()+" 设置为战斗中自动施放的技能。\n";
	}
	else
		s += "你设置哪个技能为自动施放技能？\n";
	//this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	write(s);
	write("[返回:myskills]\n");
	write("[返回游戏:look]\n");
	return 1;
}

