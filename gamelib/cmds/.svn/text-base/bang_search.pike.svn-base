#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "帮派列表:\n(在这里，点击帮名查看详细信息)\n";
	if(me->bangid != 0){
		s += "你已经在另一个帮派里了，无法申请加入其他帮派\n";
	}
	s += BANGD->query_bang_list(me);
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
