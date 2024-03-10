#include <command.h>
#include<wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	object ob = find_player(arg);
	int load_flag = 0;
	if(!ob)
	{
		ob = me->load_player(arg);           //如果此人不在线，则加载。
		load_flag =1;
	}
	if(ob){
		s += "我们的探子将在1小时内为您探查"+ob->query_name_cn()+"的行踪，不过需要2碎玉作为报酬。\n";
		s += "[确认:spy_start_confirm "+ob->query_name()+"]  ";
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
