#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "你想把谁设置为队长？\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	//only term leader can kick out termer
	if(TERMD->get_term_power(me->query_term(),me->query_name())!="leader"){
		s += "只有队长才有权限转移队长！\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	int rs;
	object ob = find_player(arg);
	if(!ob){
		s += "该用户不在线，无法进行此操作。\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	else{
		rs = TERMD->update_termLeader(me->query_term(),me->query_name(),ob->query_name(),ob->query_name_cn());
		if(rs)	
			s += "成功将 "+ob->query_name_cn()+" 设置为队长。\n";
		else	
			s += "将队员 "+ob->query_name_cn()+" 设置队长失败。\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
