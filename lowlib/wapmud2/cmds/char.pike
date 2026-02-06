#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,environment(this_player()),count);
	if(!ob){
		this_player()->write_view(WAP_VIEWD["/char_notfound"],ob);
	}
	else{
		this_player()->write_view(WAP_VIEWD["/char"],ob,this_player(),count);
	}
	return 1;
}
