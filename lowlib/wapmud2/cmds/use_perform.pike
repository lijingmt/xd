#include <command.h>
#include <wapmud2/include/wapmud2.h>


int main(string arg)
{
	if(random(100)<90){
		object me = this_player();
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
		if(this_player()->in_combat){
			this_player()->perform(arg);
			this_player()->reset_view(WAP_VIEWD["/fight"]);
			this_player()->write_view();
		}
		else{
			this_player()->reset_view(WAP_VIEWD["/look"]);
			this_player()->write_view();
		}
	}
	else{
		this_player()->write_view(WAP_VIEWD["/perform"]);
	}
	return 1;
}

