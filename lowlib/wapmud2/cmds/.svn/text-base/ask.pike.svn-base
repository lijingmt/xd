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
		//加上阵营判断

		//if(ob->is("npc")){
		//	this_player()->write_view_tmp(WAP_VIEWD["/ask"],ob,this_player(),count);
		//}
		//else{
			this_player()->write_view(WAP_VIEWD["/tell_prompt"],0,0,({ob->name,count}));
		//}
	}
	return 1;
}
