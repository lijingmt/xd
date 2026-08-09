#include <command.h>
#include <gamelib/include/gamelib.h>

private int allowed_city_route(string path,string city)
{
	mapping(string:array(string)) routes = ([
		"xiqicheng":({"jinaodao/yaozhenbiyougong",
			"kunlunshan/xianzhenxuyugong","xiqicheng/xianzhen"}),
		"chaogecheng":({"jinaodao/yaozhenbiyougong",
			"kunlunshan/xianzhenxuyugong","chaogecheng/yaozhengchaoge"}),
	]);
	return routes[city] && has_value(routes[city],path);
}
//arg = path city
int main(string|zero arg)
{
	object me=this_player();
	string path="";
	string city="";
	sscanf(arg,"%s %s",path,city);
	if(!path || !city || !allowed_city_route(path,city)){
		if(path && city)
			write("传送阵目标校验失败。\n");
		me->command("look");
		return 1;
	}
	else if(me->in_combat){
		me->command("attack");
		return 1;
	}
	path = ROOT + "/gamelib/d/" + path;
	object env=environment(me);
	if(me->query_raceId() == CITYD->query_captured(city)){
		int moved;
		mixed move_err = catch { moved = me->move(path); };
		if(move_err || !moved){
			write("传送阵暂时无法使用。\n");
			return 1;
		}
		if(env&&!env->is("character")&&!env->is("menu"))
			me->last_pos=file_name(env)-ROOT;
		me->m_delete_foruser("/tmp/tour_pos");
		me->reset_view();
		me->command("look");
		return 1;
	}
	else{
		string s = "城池已被攻占，你无法传送到达。\n";
		tell_object(me,s);
		me->reset_view();
		me->command("look");
		return 1;
	}
}
