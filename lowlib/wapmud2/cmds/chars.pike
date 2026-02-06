#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	object me = this_player();

	if(random(100)<90){
		if(!me["/tmp/atk_ctime"])
			me["/tmp/atk_ctime"] = (System.Time()->usec_full)/1000;
		else{
			if( ((System.Time()->usec_full)/1000 - me["/tmp/atk_ctime"]) <= 1200 ){
				//werror("-------- player["+me->name+"] chars difftime<=1000 --------\n");
				if(!me["/tmp/wg_times"]) me["/tmp/wg_times"] = 1;
				else me["/tmp/wg_times"]++;
			}
			else{
				me["/tmp/atk_ctime"] = (System.Time()->usec_full)/1000;
			}
		}
	}


	if(arg){
		if(arg=="npc"){
			this_player()->write_view(WAP_VIEWD["/chars_npc"]);
		}
		else if(arg=="player"){
			this_player()->write_view(WAP_VIEWD["/chars_player"]);
		}
		else{
			this_player()->write_view(WAP_VIEWD["/chars"]);
		}
	}
	else
		this_player()->write_view(WAP_VIEWD["/chars"]);
	return 1;
}
