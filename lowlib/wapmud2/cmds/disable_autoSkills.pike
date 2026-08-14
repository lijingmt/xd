#include <command.h>
#include <wapmud2/include/wapmud2.h>
#define AUTOFIGHTD ((object)(ROOT "/gamelib/single/daemons/autofightd.pike"))
int main(string arg)
{
	object me = this_player();
	string s = "";
	string name="";
	int slot;
	int removed;
	if(arg && sscanf(arg,"%s %d",name,slot)==2){
		array(string) queue=AUTOFIGHTD->query_auto_skill_queue(me);
		if(slot>=1 && slot<=3 && queue[slot-1]==name)
			removed=AUTOFIGHTD->clear_auto_skill_slot(me,slot);
	}
	else if(arg){
		name=arg;
		removed=AUTOFIGHTD->clear_selected_auto_skill(me,name);
	}
	if(removed){
		s += "你已将技能 "+
			(MUD_SKILLSD[name] ? MUD_SKILLSD[name]->query_name_cn() : name)+
			" 从自动连招中移除。\n";
	}
	else
		s += "当前没有这个自动施放技能。\n";
	write(s);
	write("[返回:myskills]\n");
	write("[返回游戏:look]\n");
	//this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
