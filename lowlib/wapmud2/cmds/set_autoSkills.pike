#include <command.h>
#include <wapmud2/include/wapmud2.h>
#define AUTOFIGHTD ((object)(ROOT "/gamelib/single/daemons/autofightd.pike"))
int main(string arg)
{
	object me = this_player();
	string s = "";
	string name="";
	int slot=1;
	if(arg && sscanf(arg,"%s %d",name,slot)!=2)
		name=arg;
	if(AUTOFIGHTD->set_selected_auto_skill(me,name,slot)){
		s += "你将技能 "+MUD_SKILLSD[name]->query_name_cn()+
			" 设置为自动连招优先"+slot+"。\n";
	}
	else
		s += "只能把自己已学会的主动技能设置到优先1至3。\n";
	//this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	write(s);
	write("[返回:myskills]\n");
	write("[返回游戏:look]\n");
	return 1;
}
