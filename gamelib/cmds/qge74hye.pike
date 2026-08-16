#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string path)
{
	object me=this_player();
	string fb_name = "";
	string fb_entrance = "";
	if(path && has_prefix(path,"jiuxiaojiejing/") &&
	   me->query_level()<ENDGAME_MAP_MIN_LEVEL &&
	   !MANAGERD->is_cross_zone_admin(me->query_name())){
		write("九霄界境需要达到"+ENDGAME_MAP_MIN_LEVEL+
			"级后才能进入。\n");
		me->command("look");
		return 1;
	}
	if(!path || search(path,"..")!=-1 || search(path,"#")!=-1 ||
	   has_prefix(path,"/")){
		if(path)
			write("目的地路径无效。\n");
		me->command("look");
		return 1;
	}
	else if(me->in_combat){
		me->command("attack");
		return 1;
	}
	//副本内部房间必须由 fb_entry 按队伍取得克隆实例。
	//兼容旧地图链接：不让玩家进入公共基础对象，改送副本入口。
	if(FBD->is_fb_room_path(path)){
		fb_name = FBD->query_fb_name_by_room_path(path);
		fb_entrance = FBD->query_fb_leave_room(fb_name);
		if(fb_entrance==""){
			write("该幻境内部地图不能直接飞入，请从幻境入口组队进入。\n");
			me->command("look");
			return 1;
		}
		write("幻境内部采用队伍独立实例，已为你改飞到入口；请和队员从入口进入。\n");
		path = fb_entrance;
	}
	path = ROOT + "/gamelib/d/" + path;
	object env=environment(me);
	int was_in_home = me->if_in_home();
	int moved;
	mixed move_err = catch { moved = me->move(path); };
	if(move_err || !moved){
		write("目的地暂时无法到达。\n[返回游戏:look]\n");
		return 1;
	}
	if(was_in_home)
		HOMED->clear_user(me);
	if(env&&!env->is("character")&&!env->is("menu"))
		me->last_pos=file_name(env)-ROOT;
	me->m_delete_foruser("/tmp/tour_pos");
	me->reset_view();
	me->command("look");
	return 1;
}
