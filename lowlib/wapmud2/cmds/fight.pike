#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name="";
	int count;
	int flg;
	sscanf(arg,"%s %d %d",name,count,flg);
	object ob=present(name,environment(this_player()),count,this_player());
	
	if(environment(this_player())->is("peaceful")){
		this_player()->write_view(WAP_VIEWD["/fight_peaceful"]);
	}
	//else if( ob&&ob->query_raceId()==this_player()->query_raceId() )
	//{
	//	this_player()->write_view(WAP_VIEWD["/emote"],0,0,"你不能攻击那个目标！\n");
	//}
	else{
		if(this_player()->fight(name,count,flg)){
			this_player()->reset_view(WAP_VIEWD["/fight"]);
			this_player()->write_view();
		}
		//else{
		//	this_player()->write_view_tmp(WAP_VIEWD["/fight_wait"],ob);
		//}

	}
	return 1;
}
