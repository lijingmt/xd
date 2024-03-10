/* wiz_qge74hye
 * @author hps
 * 可以瞬间移动
 * 指令格式 wiz_qge74hye [玩家|地图文件路径名|NPC文件路径名]
 */
#include <command.h>
#include <gamelib/include/gamelib.h>
#define HOME "~/gamelib/d/congxianzhen/congxianzhenguangchang"

int main(string arg)
{
	object me=this_player();
	//if( this_player()->query_name()!="zhubin"||this_player()->query_name()!="wangyan" )	
	//	return 1;
	if(!arg)
		arg = HOME;
	object ob=find_player(arg);
	if(!ob) {
		if(arg&&sizeof(arg)>1&&arg[0]=='~'&&arg[1]=='/')
			arg=ROOT+arg[1..];
			ob=find_object(arg);
	}
	if(!ob) ob=find_object(arg);
	if(!ob) ob=load_object(arg);
	if(!ob){
		write("不存在指定的物件.\n");
		return 1;
	}
	if(ob->is_room){
		me->move(ob);
		write("%O \n",ob);
	}
	else
		if(environment(ob)){
			me->move(environment(ob));
			write("%O \n",environment(ob));
		}
	return 1;
}
