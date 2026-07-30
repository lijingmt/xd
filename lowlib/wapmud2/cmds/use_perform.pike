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
			   (me->f_skills && (int)me->f_skills[arg]>before_cold))
				NEWBIED->record_perform(me,arg);
			me->reset_view(WAP_VIEWD["/fight"]);
			me->write_view();
		}
		else{
			me->reset_view(WAP_VIEWD["/look"]);
			me->write_view();
		}
	}
	else{
		me->write_view(WAP_VIEWD["/perform"]);
	}
	return 1;
}
