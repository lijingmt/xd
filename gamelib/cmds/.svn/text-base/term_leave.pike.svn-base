#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "你想退出哪个队伍？\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	int rs = TERMD->leave_term(arg, me->query_name(), me->query_name_cn());
	switch(rs){
		case 0:
			//s += "离开队伍失败，没有该队伍\n";
			s += "你已经离开队伍\n";
			me->set_term("noterm");
		break;
		case 1:
			s += "成功退出队伍。\n";
            		//刷新队伍
            		TERMD->flush_term(me->query_term());  
		break;
		case 2:
			s += "你现在是队长，不能退出队伍，可以解散队伍，或转移队长给其他队员再退出队伍。\n";
		break;
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
