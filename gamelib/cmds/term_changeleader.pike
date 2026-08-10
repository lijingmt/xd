#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
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
	mapping team = TERMD->query_term_m(me->query_term());
	array remote_member = arrayp(team[arg]) ? (array)team[arg] : ({});
	if((!ob && !sizeof(remote_member)) ||
	   !LOGICALZONED->can_user_action("team",me->query_name(),arg)){
		s += "该用户不在线，无法进行此操作。\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	else{
		string target_name = ob ? ob->query_name() : arg;
		string target_name_cn = ob ? ob->query_name_cn() :
			(string)remote_member[0];
		rs = TERMD->update_termLeader(me->query_term(),me->query_name(),
			target_name,target_name_cn);
		if(rs)	
			s += "成功将 "+target_name_cn+" 设置为队长。\n";
		else	
			s += "将队员 "+target_name_cn+" 设置队长失败。\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
