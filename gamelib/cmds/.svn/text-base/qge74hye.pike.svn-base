#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string path)
{
	object me=this_player();
	if(me->if_in_home())//如果玩家是在某个home中
	{
		HOMED->clear_user(me);//清除相关的信息 Evan 2008.09.21
	}
	if(!path){
		me->command("look");
		return 1;
	}
	else if(me->in_combat){
		me->command("attack");
		return 1;
	}
	path = ROOT + "/gamelib/d/" + path;
	object env=environment(me);
	if(env&&!env->is("character")&&!env->is("menu")){
		me->last_pos=file_name(env)-ROOT;
	}
	me->_m_delete("/tmp/tour_pos");
	me->move(path);
	me->reset_view();
	me->command("look");
	return 1;
}
