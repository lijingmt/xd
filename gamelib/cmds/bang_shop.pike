#include <command.h>
#include <gamelib/include/gamelib.h>
// 帮贡商店页面。
int main(string|zero arg)
{
	object me = this_player();
	if(!me)
		return 0;
	me->write_view(WAP_VIEWD["/emote"],0,0,
		BANGPAI_EXTD->query_bang_shop_page(me));
	return 1;
}
