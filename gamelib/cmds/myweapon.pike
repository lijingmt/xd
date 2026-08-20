#include <command.h>
#include <gamelib/include/gamelib.h>

// 兼容历史装备入口；真实装备页由 mytools 维护。
int main(string|zero arg)
{
	object me = this_player();
	me->command("mytools");
	return 1;
}
