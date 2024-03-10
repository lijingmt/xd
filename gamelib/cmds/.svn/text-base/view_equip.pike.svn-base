#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	object ob = find_player(arg);
	if(ob){
		s += ob->query_name_cn()+"：\n";
		s += ob->view_equip();
	}
	else
		s += "你要观察的对象并不存在\n";
	//s += "[返回:char "+arg+"]\n";
	//s += "[返回游戏:look]\n";
	//write(s);
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
