#include <command.h>
#include <gamelib/include/gamelib.h>
#define SPEC  900
int main(string arg)
{
	string s = "";
	object me=this_player();
	object to;
	if(me->in_combat){
		me->command("attack");
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
				object room = clone(path);
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
						if(me->if_in_home())//如果玩家是在某个home中
						{
							HOMED->clear_user(me);//清除相关的信息 Evan 2008.09.21
						}
						me->move(path);
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
