#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "你要邀请谁加入队伍？";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	else{
		object ob = find_player(arg);
		if(ob){
			if(ob->query_term()!=""&&ob->query_term()!="noterm"){
				s += "对方已经加入了某个队伍，请返回。\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			if(ob->query_name()==me->query_name())
				s += "你不能自己邀请自己，请返回。\n";
			else{
				tell_object(ob,me->query_name_cn()+"邀请你加入一个队伍，是否同意？\n[同意:term_ok "+me->query_name()+"] [拒绝:term_refuse "+me->query_name()+"]\n");	
				s += "组队邀请已经发出，请返回等待对方是否愿意加入队伍。\n";
			}
		}
		else{
			s += "你要邀请谁加入队伍？";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
