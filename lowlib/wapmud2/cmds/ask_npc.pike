#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,environment(this_player()),count);
	if(!ob){
		this_player()->write_view(WAP_VIEWD["/ask_notfound"],ob);
	}
	else{
		if(ob->is("npc"))
			this_player()->write_view(WAP_VIEWD["/ask_npc"],ob,this_player(),count);
	}
	return 1;
}
