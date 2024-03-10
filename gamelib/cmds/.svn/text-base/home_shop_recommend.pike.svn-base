#include <command.h>
#include <gamelib/include/gamelib.h>

//点击店铺推荐链接调用的指令，该指令主要实现列出已经推荐且没过期的店铺

int main(string arg)
{
	string s = "";
	object me = this_player();
	s += "店铺推荐：\n\n";
	s += HOMED->query_shopRcm_list();
	s += "\n\n";
	s += "[推荐我的店铺:home_shop_recommend_confirm]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
