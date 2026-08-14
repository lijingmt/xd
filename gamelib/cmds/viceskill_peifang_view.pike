#include <command.h>
#include <gamelib/include/gamelib.h>

// arg = "duanzao", "liandan", "caifeng" or "zhijia"
string query_peifang_shop_text(string|zero arg)
{
	string s = "你只有学会了相关的手艺，才能读懂这些配方。\n";
	if(arg == "duanzao")
		s += PEIFANGD->query_duanzao_peifang_list(1,20);
	else if(arg == "liandan")
		s += PEIFANGD->query_liandan_peifang_list(1,20);
	else if(arg == "caifeng")
		s += PEIFANGD->query_caifeng_peifang_list(1,20);
	else if(arg == "zhijia")
		s += PEIFANGD->query_zhijia_peifang_list(1,20);
	else
		s += "这里没有这种配方。\n";
	s += "[返回游戏:look]\n";
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	me->write_view(WAP_VIEWD["/emote"],0,0,
		query_peifang_shop_text(arg));
	return 1;
}
