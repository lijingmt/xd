#include <command.h>
#include <gamelib/include/gamelib.h>
//传音符使用ui
int main(string arg)
{
	object me = this_player();
	int sub_time = 0;
	/*
	if(me->query_level()<30){
		me->write_view(WAP_VIEWD["/emote"],0,0,"您的等级过低，看不懂这灵符上文字的意义。\n");
		return 1;
	}
	*/
	sub_time = time() - me["/bc_time"];
	if(sub_time<=60){
		me->write_view(WAP_VIEWD["/emote"],0,0,"传音符不可频繁使用，请您稍候再用。\n");
		return 1;
	}
	string s = "请输入您想说的话：\n";
	s += "[string word:...]\n";
	s += "[submit 确定:bc_confirm ...]\n";
	s += "\n[返回:popview]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
