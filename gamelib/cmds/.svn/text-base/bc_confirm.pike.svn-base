#include <command.h>
#include <gamelib/include/gamelib.h>
#define ITEM_PATH ROOT "/gamelib/clone/item/other/" 
int main(string arg)
{
	object me = this_player();
	string s = "";
	string re = "";
	string bc_name = "qianlichuanyinfu";
	int bc_count = 0;
	object bc = present(bc_name,me,bc_count);
	if(!bc){
		me->write_view(WAP_VIEWD["/emote"],0,0,"对不起，您现在没有这样的灵符，无法向世界宣言。\n");
		return 1;
	}
	if((time() - me["/bc_time"])<=60){
		me->write_view(WAP_VIEWD["/emote"],0,0,"传音符不可频繁使用，请您稍候再用。\n");
		return 1;
	}
	sscanf(arg,"word=%s",s);
	//werror("------------what's wrong with s "+s+"-----------\n");
	if(!s||s==""){
		me->write_view(WAP_VIEWD["/emote"],0,0,"您什么话也没说，灵符不接受您的这种用法。\n");
		return 1;
	}
	if(sizeof(s)>40){
		me->write_view(WAP_VIEWD["/emote"],0,0,"您的话语含有非法信息或超出限制，请重新输入。\n");
		return 1;
	}
	array(string) msg=({});
	msg += ({GAME_NAME_S});
	msg += ({me->query_name()});
	msg += ({me->query_name_cn()});
	msg += ({"大喇叭"});
	msg += ({s});
	msg += ({WAP_HONERD->query_honer_level_desc(me->honerlv,me->query_raceId())});
	if(BROADCASTD->bcSend(msg))
	{
		re+="进光闪过，灵符飞天，您的话语将惊显于天下。千里传音符消失不见了！\n";
		me->remove_combine_item("qianlichuanyinfu",1);
		me["/bc_time"] = time();
		re += "\n[返回:popview]\n";
		re += "[返回游戏:look]\n";
		write(re);
		return 1;
	}
	else
	{
		re+="您的话语含有非法字符或字数超出限制，请重新输入。\n";
	}
	re += "\n[返回:popview]\n";
	re += "[返回游戏:look]\n";
	write(re);
	return 1;
}
