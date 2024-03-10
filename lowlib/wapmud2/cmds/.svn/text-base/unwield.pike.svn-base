#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,this_player(),count);
	if(this_player()->unwield(ob)){
		this_player()->pop_view();
		this_player()->write_view(WAP_VIEWD["/unwield"],ob);
	}
	else{
		this_player()->pop_view();
		this_player()->write_view(WAP_VIEWD["/unwield_notfound"]);
	}
	return 1;
}
