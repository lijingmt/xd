#include <command.h>
#include<wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	string uid = arg;
	object ob = find_player(uid);
	int load_flag = 0;
	if(!ob)
	{
		ob = me->load_player(uid);           //如果此人不在线，则加载。
		load_flag =1;
	}
	if(ob){
		s += "你将把"+ob->query_name_cn()+"加入到关注列表，在好友链接里可以随时购买到该玩家的情报。\n";
		s += "[确认:spy_add_confirm "+ob->query_name()+"] ";
		s += "[放弃:popview]\n";
	}
	else
		s += "你要关注的对象并不存在。\n";
	if(load_flag)
	{
		ob->remove(); //将加载的玩家踢下线，同时改变标志位。
		load_flag=0;
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
