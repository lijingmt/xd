#include <command.h>
#include <gamelib/include/gamelib.h>

// 兼容旧兑换书签；真实列表命令是 fee_exchange_list。
int main(string|zero arg)
{
	object me = this_player();
	me->command("fee_exchange_list");
	return 1;
}
