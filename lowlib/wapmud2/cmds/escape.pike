#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	if(this_player()->in_combat){
		this_player()->set_action("escape");
		//this_player()->escape();
		this_player()->write_view();
	}
	else{
		this_player()->reset_view(WAP_VIEWD["/look"]);
		this_player()->write_view();
	}
	return 1;
}

