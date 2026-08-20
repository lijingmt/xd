#include <command.h>
#include <gamelib/include/gamelib.h>

// 兼容远古客服页的 gamehelp 0 入口。
int main(string|zero arg)
{
	object me = this_player();
	me->command("newbie_guide overview");
	return 1;
}
