//玩家查看详细奖品信息，并参与该级别的抽奖
//arg = lv 抽奖的级别
#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	int lv = (int)arg;
	s += LOTTERYD->query_lottery_award_detail(lv);
	s += "[返回:lottery_view_list]\n";
	s += "[返回妙坊:yushi_myzone]\n";
	s +="[返回游戏:look]\n";
	write(s);
	return 1;
}
