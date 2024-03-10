//用户进入装备抽奖功能页面调用，可以查看到当前正在抽奖的情况
#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "来吧~考验自己rp的时候到了！\n";
	s += "你可以：\n";
	s += "点击奖品即可查看详情，并参与这个该级别的抽奖\n";
	s += LOTTERYD->query_lottery_on();
	s += "也可以：\n[全级别范围抽奖:lottery_join_in](2碎玉/次)\n";
	s += "--------\n";
	s += "[返回:yushi_myzone]\n";
	s +="[返回游戏:look]\n";
	write(s);
	return 1;
}
