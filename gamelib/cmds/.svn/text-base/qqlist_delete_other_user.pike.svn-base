#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "您确定要删除未分组里的所有好友吗?\n\n";
		s += "[确定删除:qqlist_delete_other_user yes]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	} 
	if(arg == "yes"){
		int t = me->qqlist_delete_other_user();
		if(t)
			s += "操作已成功，请返回。\n";
		else
			s += "操作失败，请返回重试。\n";
	
	}
	s += "[返回:my_qqlist]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
