#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	object env=environment(this_player());
	if(this_player()->hind == 0){
		env->deleteLeaveInfo(this_player()->name);
		env->addArriveMSG(this_player());
	}
	this_player()->reset_view(WAP_VIEWD["/arrive"]);
	this_player()->write_view();
	return 1;
}
