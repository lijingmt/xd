#include <command.h>
#include <gamelib/include/gamelib.h>
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
	int ran = me->query_level();
	path = ROOT + "/gamelib/d/" + path;
	object env=environment(me);
	if(env->query_name() != "mengduya"){
		me->command("look");
		return 1;
	}
	if(ran >= random(45)){
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
		string s = "Ҳ���ǹ���������Ҳ������������~��֮����׹�������ˡ�\n";
		tell_object(me,s);
		me->set_life(1);
		if(me->relife){
			mixed err=catch{
				(object)(ROOT+me->relife);
			};
			if(!err)
				me->move(ROOT+me->relife);
		}
		else{
			//û�и���㣬��Ĭ����Ӫ����ظ���
			if(me->query_raceId()=="human")
				me->last_pos="/gamelib/d/congxianzhen/congxianzhenguangchang";
			if(me->query_raceId()=="monst")
				me->last_pos="/gamelib/d/jinaodao/yuhuacunguangchang";
			if(me->last_pos){
				mixed err=catch{
					(object)(ROOT+me->last_pos);
				};
				if(!err)
					me->move(ROOT+me->last_pos);
			}
		}
		me->reset_view();
		me->command("look");
		return 1;
	}
}
