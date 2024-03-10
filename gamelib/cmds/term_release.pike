#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "你想解散哪个队伍？\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	int rs = TERMD->destory_term(arg, me->query_name());
	switch(rs){
		case 0:
			s += "解散失败，没有该队伍\n";
		break;
		case 1:
			s += "成功解散队伍。\n";
            //刷新队伍
            TERMD->flush_term(me->query_term());  
		break;
		case 2:
			s += "解散失败,未找到该队伍。\n";
		break;
		case 3:
			s += "解散失败,未找到该队伍。\n";
		break;
		case 4:
			s += "非队长权限，不能解散队伍\n";
		break;
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
