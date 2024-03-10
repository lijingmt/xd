#include <command.h>
#include <gamelib/include/gamelib.h>
#define SPEC  900
int main(string arg)
{
	string s = "";
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
			s += "[返回:myskills]\n";
			s += "[返回游戏:look]\n";
			write(s);
		}
		else if(flag == 1){
			if(me->get_cur_mofa()<300){
				s += "没有足够的法力施放影遁\n";
				s += "[返回:myskills]\n";
				s += "[返回游戏:look]\n";
				write(s);
			}
			else if(me["/spec_skill/coldtime"]>time()){
				s += "技能尚未冷却\n";
				s += "[返回:myskills]\n";
				s += "[返回游戏:look]\n";
				write(s);
			}
			else{
				me->hind = 1;
				me->set_mofa(me->get_cur_mofa()-300);
				me["/spec_skill/coldtime"] = time()+SPEC;
				me->reset_view();
				me->command("look");
			}
		}
	}
	return 1;
}
