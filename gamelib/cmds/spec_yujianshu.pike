#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	int flag;
	string s = "";
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
		s += "御剑而行，能快速到达队友身边，耗法300，冷却时间15分钟\n";
		sscanf(arg,"%d",flag);
		if(flag == 0){
			s += "技能尚未冷却\n";
			s += "[返回:myskills]\n";
			s += "[返回游戏:look]\n";
			write(s);
		}
		else if(flag == 1){
			if(me->get_cur_mofa()<300){
				s += "没有足够的法力施放御剑术\n";
				s += "[返回:myskills]\n";
				s += "[返回游戏:look]\n";
				write(s);
			}
			else{
				s += "点击飞向队友:\n";
				mapping(string:array) map_term = ([]);
				map_term = (mapping)TERMD->query_term_m(me->query_term());
				if(map_term&&sizeof(map_term)){
					foreach(indices(map_term),string uid){
						object termer = find_player(uid);
						if(termer && termer->query_name() != me->query_name()){
							object env = environment(termer);
							s += "["+termer->query_name_cn()+":spec_yujian_to "+uid+"]("+env->query_name_cn()+")\n";
						}
					}
				}
				else
					s += "你目前并没有队友\n";
				s += "[返回:myskills]\n";
				s += "[返回游戏:look]\n";
				write(s);
			}
		}
	}
	return 1;
}
