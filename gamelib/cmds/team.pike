#include <command.h>
#include <gamelib/include/gamelib.h>

// 兼容历史链接与旧书签；新界面统一使用 my_term。
int main(string|zero arg)
{
	object me = this_player();
	me->command("my_term");
	return 1;
}
