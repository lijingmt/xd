#include <command.h>
#include<wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	string uid =arg;
	int load_flag = 0;
	object ob = find_player(uid);
	if(!ob){
		ob = me->load_player(uid);
		load_flag =1;
	}
	if(me->is_spied(uid))
		s += "您正在密切关注 "+ob->query_name_cn()+" 的行踪，从列表中删除后将无法再得知其行踪，确认要删除吗?\n";
	else
		s += "你将把"+ob->query_name_cn()+"移除关注列表，确认要这么做吗？\n";
	s += "[确认:spy_del_confirm "+uid+"]  ";
	s += "[放弃:popview]\n";

	if(load_flag)
	{
		ob->remove(); //将加载的玩家踢下线
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
