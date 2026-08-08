#include <command.h>
#include <gamelib/include/gamelib.h>  
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/" 
//姝ゆ寚浠よ幏寰楃帀鐭筹紝鐢ㄤ簬娴嬭瘯
int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	if(!me || MANAGERD->checkpower(me->query_name())!="admin"){
		write("该调试命令仅限管理员使用。\n[返回游戏:look]\n");
		return 1;
	}
	object ob = clone(YUSHI_PATH+"suiyu");
	if(ob){
		ob->amount = 20;
		s += "获得"+ob->query_short()+"\n";
		ob->move_player(me->query_name());
	}
	ob = clone(YUSHI_PATH+"xianyuanyu");
	if(ob){
		ob->amount = 20;
		s += "获得"+ob->query_short()+"\n";
		ob->move_player(me->query_name());
	}
	ob = clone(YUSHI_PATH+"linglongyu");
	if(ob){
		ob->amount = 20;
		s += "获得"+ob->query_short()+"\n";
		ob->move_player(me->query_name());
	}
	ob = clone(YUSHI_PATH+"biluanyu");
	if(ob){
		ob->amount = 20;
		s += "获得"+ob->query_short()+"\n";
		ob->move_player(me->query_name());
	}
	ob = clone(YUSHI_PATH+"xuantianbaoyu");
	if(ob){
		ob->amount = 20;
		s += "获得"+ob->query_short()+"\n";
		ob->move_player(me->query_name());
	}
	tell_object(me,s);
	me->command("look");
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "\n[返回游戏:look]\n";
	return 1;
}
