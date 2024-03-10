#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = termid flag
//flag = 1 表示此时队长，可分配仓库里的东西
//     = 0 表示队员，只可能查看
int main(string arg)
{
	string s = "";
	object me=this_player();
	string termid = "";
	int flag = 0;
	sscanf(arg,"%s %d",termid,flag);
	string team_id = me->query_term();
	if(team_id == "noterm" || team_id != termid){
		s += "你已经没有在这个队伍里了\n";
		s += "[返回:look]\n";
		write(s);
		return 1;
	}
	else{
		s += "队伍仓库：\n";
		s += "暂时存放着首领怪掉落的物品，队长可以分配这些物品\n";
		s += "【注意】：请队长及时分配，仓库的东西将在队伍解散时消失\n";
		s += "--------\n";
		s += TERMD->query_termItems(termid,flag);
	}
	s += "\n[返回:my_term]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
