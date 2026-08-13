#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string path)
{
	object me=this_player();
	if(!path || path!="waihai/wenshuidai"){
		if(path)
			write("跳崖目标校验失败。\n");
		me->command("look");
		return 1;
	}
	else if(me->in_combat){
		me->command("attack");
		return 1;
	}
	int ran = me->query_level();
	path = ROOT + "/gamelib/d/" + path;
	object env=environment(me);
	if(!env || env->query_name() != "mengduya"){
		me->command("look");
		return 1;
	}
	if(ran >= random(45)){
		if(env&&!env->is("character")&&!env->is("menu")){
			me->last_pos=file_name(env)-ROOT;
		}
		int moved;
		mixed move_err=catch { moved=me->move(path); };
		if(move_err || !moved){
			write("跳崖落点暂时无法到达。\n");
			return 1;
		}
		me->m_delete_foruser("/tmp/tour_pos");
		me->reset_view();
		me->command("look");
		return 1;
	}
	else{
		string s = "也许是功力不够，也许是运气不好~总之，你坠崖身亡了。\n";
		tell_object(me,s);
		me->set_life(1);
		int revived;
		if(me->relife && me->is_valid_relife_path(me->relife)){
			mixed revive_err=catch {
				revived=me->move(ROOT+me->relife);
			};
			if(revive_err)
				revived=0;
		}
		if(!revived){
			//没有复活点，从默认阵营复活地复活
			if(me->query_raceId()=="human")
				me->last_pos="/gamelib/d/congxianzhen/congxianzhenguangchang";
			if(me->query_raceId()=="monst")
				me->last_pos="/gamelib/d/jinaodao/yuhuacunguangchang";
			if(me->query_raceId()=="third"){
				if(random(2)==0)
					me->last_pos="/gamelib/d/congxianzhen/congxianzhenguangchang";
				else
					me->last_pos="/gamelib/d/jinaodao/yuhuacunguangchang";
			}
			if(me->last_pos){
				mixed fallback_err=catch {
					revived=me->move(ROOT+me->last_pos);
				};
				if(fallback_err)
					revived=0;
			}
		}
		if(!revived)
			werror("[WAIHAI] revive movement failed userid=%s\n",
				me->query_name());
		me->reset_view();
		me->command("look");
		return 1;
	}
}
