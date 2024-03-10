#include <command.h>
#include <gamelib/include/gamelib.h>
//列出玩家身上可替换的背包
int main(string arg)
{
	object me = this_player();
	string s="";
	string type = "";
	int pac_size = 0;
	string tmp_s = "";
	sscanf(arg,"%s %d",type,pac_size);
	if(type=="beibao")tmp_s = "背包";
	if(type=="cangku")tmp_s = "仓库";
	s += "您已购买的"+tmp_s+"有：\n";
	s += BUYD->get_pac_replace_list(me,type,pac_size);
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
