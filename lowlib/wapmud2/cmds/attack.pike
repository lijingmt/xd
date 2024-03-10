#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	if(random(100)<90){
		object me = this_player();
		if(!me["/tmp/atk_ctime"])
			me["/tmp/atk_ctime"] = (System.Time()->usec_full)/1000;
		else{
			if( ((System.Time()->usec_full)/1000 - me["/tmp/atk_ctime"]) <= 500 ){
				//werror("-------- player["+me->name+"] attack difftime<=500 --------\n");
				//调用flushview的业务处理，等于刷新页面，从viewstack堆栈中推出上一个
				//this_player()->write_view();
				//return 1;
				if(!me["/tmp/wg_times"]) me["/tmp/wg_times"] = 1;
				else me["/tmp/wg_times"]++;
			}
			else{
				me["/tmp/atk_ctime"] = (System.Time()->usec_full)/1000;
				//正常调用，未触发连击，状态记数--
				//if(!me["/tmp/wg_times"]) me["/tmp/wg_times"] = 1;
				//else me["/tmp/wg_times"]--;
				//if(me["/tmp/wg_times"]<=0) me["/tmp/wg_times"] = 1;
			}
		}
	}

	if(this_player()->in_combat){
		this_player()->reset_view(WAP_VIEWD["/fight"]);
		this_player()->write_view();
	}
	else{
		this_player()->reset_view(WAP_VIEWD["/look"]);
		this_player()->write_view();
	}
	return 1;
}
