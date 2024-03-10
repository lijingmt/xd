#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = path city
int main(string arg)
{
	object me=this_player();
	string path="";
	string city="";
	sscanf(arg,"%s %s",path,city);
	if(!path || !city){
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
		if(env&&!env->is("character")&&!env->is("menu")){
			me->last_pos=file_name(env)-ROOT;
		}
		me->_m_delete("/tmp/tour_pos");
		me->move(path);
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
