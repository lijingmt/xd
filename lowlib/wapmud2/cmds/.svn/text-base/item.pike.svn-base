#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,environment(this_player()),count);
	if(ob){
		if(ob->item_canGet==0){
			this_player()->write_view(WAP_VIEWD["/item_canNotGet"],ob);
		}
		else if(ob->is("equip")){
			this_player()->write_view(WAP_VIEWD["/item_equip"],ob);
		}
		else if(ob->query_item_type()=="source"){
			this_player()->write_view(WAP_VIEWD["/item_source"],ob);	
		}
		else{
			this_player()->write_view(WAP_VIEWD["/item"],ob);
		}
	}
	else{
		this_player()->write_view(WAP_VIEWD["/item_notfound"]);
	}
	return 1;
}
