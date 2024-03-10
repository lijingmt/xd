#include <command.h>
#include <gamelib/include/gamelib.h>
//查看兑换来的领取列表的指令
int main(string arg)
{
	object me = this_player();
	string s = "可供你领取的列表，点击即可完成领取操作：\n";
	s += FEE_EXCHANGED->query_fetch_list(me->query_name());
	s += "--------\n";
	s += "[返回:fee_exchange_list]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
