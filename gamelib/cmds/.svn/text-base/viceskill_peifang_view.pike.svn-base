#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = "duanzao" or "lianjin"
int main(string arg)
{
	string s = "你只有学会了相关的技能，才能读懂这些卷轴上的东西\n";
	object me=this_player();
	if(arg == "duanzao")
		s += PEIFANGD->query_duanzao_peifang_list(1,20);
	if(arg == "liandan")
		s += PEIFANGD->query_liandan_peifang_list(1,20);
	if(arg == "caifeng")
		s += PEIFANGD->query_caifeng_peifang_list(1,20);
	if(arg == "zhijia")
		s += PEIFANGD->query_zhijia_peifang_list(1,20);
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "\n[返回游戏:look]\n";
	//write(s);
	return 1;
}
