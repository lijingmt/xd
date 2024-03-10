#include <command.h>
#include <wapmud2/include/wapmud2.h>
//此指令用于跟随同队的人
int main(string arg)
{
	string name=arg;
	int count;
	int flag = 0;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,environment(this_player()),count,this_player());
	if(!ob){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,"你跟随的目标不存在！\n");
		return 1;
	}
	else if(this_player()->follow != "_none"){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,"你无法跟随多个目标！\n");
		return 1;
	}
	else if(environment(this_player())->query_name() == environment(ob)->query_name()){
		if(ob->follow_me == ({}))
			ob->follow_me = ({this_player()->query_name()});
		else
			ob->follow_me += ({this_player()->query_name()});
		this_player()->follow = ob->query_name();
		this_player()->command("look");
		return 1;
	}
	else
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,"无法跟随！\n");
	return 1;
}
