#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	int before_mofa = me->get_cur_mofa();
	int before_cold = 0;

	if(arg && me->f_skills)
		before_cold = (int)me->f_skills[arg];
	if(random(100)<90){
		if(!me["/tmp/pfm_ctime"])
			me["/tmp/pfm_ctime"] = (System.Time()->usec_full)/1000;
		else{
			if( ((System.Time()->usec_full)/1000 - me["/tmp/pfm_ctime"]) <= 1200 ){
				werror("-------- player["+me->name+"] perform difftime<=500 --------\n");
				//调用flushview的业务处理，等于刷新页面，从viewstack堆栈中推出上一个
				//this_player()->write_view();
				//return 1;
				if(!me["/tmp/wg_times"]) me["/tmp/wg_times"] = 1;
				else me["/tmp/wg_times"]++;
			}
			else{
				me["/tmp/pfm_ctime"] = (System.Time()->usec_full)/1000;
				//正常调用，未触发连击，--
				//if(!me["/tmp/wg_times"]) me["/tmp/wg_times"] = 1;
				//else me["/tmp/wg_times"]--;
				//if(me["/tmp/wg_times"]<=0) me["/tmp/wg_times"] = 1;
			}
		}
	}

	if(arg){
		if(me->in_combat){
			me->perform(arg);
			if(me->get_cur_mofa()<before_mofa ||
			   (me->f_skills && (int)me->f_skills[arg]>before_cold)){
				NEWBIED->record_perform(me,arg);
				if(me->query_profeId()=="lingyi")
					PROFESSIONVIPD->record_lingyi_action(me,arg);
			}
			// 金蝉魅影等技能会在 perform() 内主动脱离战斗。
			// 必须依据施放后的状态选视图，否则会把已无目标的人物
			// 强制送回战斗页，产生空白页面并遮住影遁与冷却反馈。
			if(me->in_combat)
				me->reset_view(WAP_VIEWD["/fight"]);
			else
				me->reset_view(WAP_VIEWD["/look"]);
			me->write_view();
		}
		else{
			if(me->query_profeId()=="lingyi"){
				me->perform_support(arg);
				if(me->get_cur_mofa()<before_mofa ||
				   (me->f_skills && (int)me->f_skills[arg]>before_cold)){
					NEWBIED->record_perform(me,arg);
					PROFESSIONVIPD->record_lingyi_action(me,arg);
				}
			}
			else if(before_cold>1)
				tell_object(me,"该技能还需要"+(before_cold-1)+
					"秒冷却时间，当前不在战斗中。\n");
			else
				tell_object(me,"当前不在战斗中，无法施放该技能。\n");
			me->reset_view(WAP_VIEWD["/look"]);
			me->write_view();
		}
	}
	else{
		me->write_view(WAP_VIEWD["/perform"]);
	}
	return 1;
}
