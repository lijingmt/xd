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
			// 回城目标只能使用人物档案中经过校验的复活点。
			if(!me->relife || !me->is_valid_relife_path(me->relife)){
				tell_object(me,"你的复活点无效，请先在合法卧室重新设置。\n");
				return 1;
			}
			path = ROOT + me->relife;
			object env=environment(me);
			int was_in_home = me->if_in_home();
			int moved;
			mixed move_err = catch { moved = me->move(path); };
			if(move_err || !moved){
				tell_object(me,"回城失败，请稍后重试。\n");
				return 1;
			}
			if(was_in_home)
				HOMED->clear_user(me);
			if(env&&!env->is("character")&&!env->is("menu")){
				me->last_pos=file_name(env)-ROOT;
			}
			me->m_delete_foruser("/tmp/tour_pos");
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
