#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "你想将哪位队员移出队伍？\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	//only term leader can kick out termer
	if(TERMD->get_term_power(me->query_term(),me->query_name())!="leader"){
		s += "只有队长才有这个权限！\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	int rs;
	object ob = find_player(arg);
	if(!ob){
		s += "该队员不在线，请返回。\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	else{
		rs = TERMD->kick_termer(me->query_term(), ob->query_name(), ob->query_name_cn());
		switch(rs){
			case 0:
				s += "移出队员 "+ob->query_name_cn()+" 失败\n";
				break;
			case 1:
				s += "成功移出队员 "+ob->query_name_cn()+"\n";
				//刷新队伍
				TERMD->flush_term(me->query_term());
				break;
			case 2:
				s += "你没有这个权限，请返回。\n";
				break;
		}
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
