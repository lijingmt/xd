#include <command.h>
#include <gamelib/include/gamelib.h>
#define limitpost 900
int main(string path)
{
	object me=this_player();
	if(!path){
		me->command("look");
		return 1;
	}
	else if(me->in_combat){
		me->command("attack");
		return 1;
	}
	else{
		int time_limit = time() - (int)me["/post/posttime"];
		if(time_limit>=limitpost){
			path = ROOT + path;
			object env=environment(me);

			//如果玩家在某个家园（自己或别人）中，则要清除该玩家在该home中的记录
			if(me->if_in_home())
				HOMED->clear_user(me);

			if(env&&!env->is("character")&&!env->is("menu")){
				me->last_pos=file_name(env)-ROOT;
			}
			me->_m_delete("/tmp/tour_pos");
			me->move(path);
			me["/post/posttime"] = time();
			me->reset_view();
			me->command("look");
		}
		else{
			int mint = (limitpost-time_limit)/60;
			if(mint==0)
				mint = 1;
			tell_object(me,"你还需要 "+mint+" 分钟才能使用传送功能。\n");
		}
	}
	return 1;
}
