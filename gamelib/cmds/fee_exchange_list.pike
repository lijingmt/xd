#include <command.h>
#include <gamelib/include/gamelib.h>
//进入游戏货币兑换功能的指令
int main(string arg)
{
	object me = this_player();
	string s = "[url 欢乐棋牌:http://wap.doggame.net/pokegame/index.jsp]\n游戏间兑换\n";
	s += "[活动说明:fee_exchange_readme]\n";
	s += "在这里你可以领取欢乐棋牌玩家用筹码为你兑换的玉石\n";
	s += "[领取兑换来的玉石:fee_exchange_fetch_list]\n";
	s += "也可以将玉石兑换为欢乐棋牌的筹码\n";
	s += "[兑换棋牌筹码:fee_exchange_to_detail qp0]\n";
	s += "--------\n";
	s += "[返回:yushi_myzone]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
