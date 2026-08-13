#include <command.h>
#include <gamelib/include/gamelib.h>
#define SPEC  900
int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	object to;
	if(me->in_combat){
		me->command("attack");
		return 1;
	}
	if(me->get_cur_mofa()<300){
		write("没有足够的法力施放御剑术。\n[返回:myskills]\n");
		return 1;
	}
	if(me["/spec_skill/coldtime"]>time()){
		s += "技能尚未冷却\n";
		s += "[返回:myskills]\n";
		s += "[返回游戏:look]\n";
		write(s);
	}
	else{
		to = find_player(arg);
		if(to && (!LOGICALZONED->can_interact(me,to) ||
		   me->query_term()=="" || me->query_term()=="noterm" ||
		   to->query_term()!=me->query_term()))
			to = 0;
		if(to){
			object env = environment(to);
			if(env&&!env->is("character")&&!env->is("menu")){
				string path = file_name(env);
				path = (path/"#")[0];
				if(path == "0"){
					s += "对方在幻境，无法飞到\n";
					s += "[再试一次:spec_yujianshu 1]\n";
					s += "[返回:myskills]\n";
					s += "[返回游戏:look]\n";
					write(s);
					return 1;

				}
				object room = env;
				array(string) tmp = path/"/";
				int num = sizeof(tmp);
				string roomName = tmp[num-2];
				if(room){
					if(room->query_room_type() == "fb"){
						s += "对方在幻境，无法飞到\n";
						s += "[再试一次:spec_yujianshu 1]\n";
						s += "[返回:myskills]\n";
						s += "[返回游戏:look]\n";
						write(s);
					}
					else if(me->query_level() < 58 && roomName == "penglaihuanjing"){
						s += "你的等级太低，无法飞到\n";
						s += "[再试一次:spec_yujianshu 1]\n";
						s += "[返回:myskills]\n";
						s += "[返回游戏:look]\n";
						write(s);
					}
					else if(room->query_room_type() =="home")
					{
						s += "对方在家园中，无法飞到\n";
						s += "[再试一次:spec_yujianshu 1]\n";
						s += "[返回:myskills]\n";
						s += "[返回游戏:look]\n";
						write(s);
					}
					else{
						int was_in_home = me->if_in_home();
						int moved;
						mixed move_err = catch { moved = me->move(path); };
						if(move_err || !moved){
							write("御剑失败，目的地暂时无法到达。\n[返回游戏:look]\n");
							return 1;
						}
						if(was_in_home)
							HOMED->clear_user(me);
						me->set_mofa(me->get_cur_mofa()-300);
						me["/spec_skill/coldtime"] = time()+SPEC;
						me->reset_view();
						me->command("look");
					}
				}
				else{
					s += "无法飞到，请尝试其他队友\n";
					s += "[再试一次:spec_yujianshu 1]\n";
					s += "[返回游戏:look]\n";
					write(s);
				}
			}
			else{
				s += "无法飞到，请尝试其他队友\n";
				s += "[再试一次:spec_yujianshu 1]\n";
				s += "[返回游戏:look]\n";
				write(s);
			}
		}
		else{
			s += "没有此队友或者已经下线\n";
			s += "[再试一次:spec_yujianshu 1]\n";
			s += "[返回游戏:look]\n";
			write(s);	
		}
	}
	return 1;
}
