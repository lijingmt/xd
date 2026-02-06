#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	if(arg==0){
		this_player()->write_view(WAP_VIEWD["/qqlist"]);
		return 1;
	}
	else{
		if(this_player()->query_name()==arg){
			this_player()->write_view(WAP_VIEWD["/qqlist_insert_self"]);
			return 1;
		}
		object ob=find_player(arg);
		int remove_flag=0;
		if(!ob){
			ob=this_player()->load_player(arg);
			remove_flag=1;
		}
		if(ob){
			if(ob->sid == "5dwap"){
				this_player()->write_view(WAP_VIEWD["/qqlist_insert_guest_other"],ob);
				return 1;
			}
			if(this_player()->query_raceId()==ob->query_raceId()){
				this_player()->qqlist_insert(arg);
				this_player()->write_view(WAP_VIEWD["/qqlist_insert"],ob);
			}
			else
				this_player()->write_view(WAP_VIEWD["/qqlist_insert_noSameRace"],ob);
			if(remove_flag) ob->remove();
			return 1;
		}
		else
			this_player()->write_view(WAP_VIEWD["/qqlist_insert_notOnline"]);
	}
	return 1;
}
