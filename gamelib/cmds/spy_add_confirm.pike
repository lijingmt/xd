#include <command.h>
#include<wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	object ob = find_player(arg);
	string uid ="";
	sscanf(arg,"%s",uid);
	if(!LOGICALZONED->can_user_interact(me->query_name(),uid)){
		write("逻辑分区隔离中，无法关注该玩家。\n[返回游戏:look]\n");
		return 1;
	}
	int result = me->insert_spy_info(uid);
	switch(result){
		case 0:
			s += "你关注的玩家已经达到10个，请删除一些后再来吧。\n";
			break;
		case 1:
			s += "该玩家已经在你的关注里面了，不要重复添加哦。\n";
			break;
		case 2:
			if(ob)
				s += "恭喜，你已经把"+ob->query_name_cn()+"添加到关注列表，在好友链接里可以随时购买该玩家的情报。\n";
			else
				s += "添加成功；该玩家目前离线，可在关注列表中查看。\n";
			break;
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
