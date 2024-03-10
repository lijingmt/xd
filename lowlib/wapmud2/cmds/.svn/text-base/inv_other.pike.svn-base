#include <command.h>
#include <wapmud2/include/wapmud2.h>
//arg = player_name ob_name ob_count
int main(string arg)
{
	if(!arg){
		write("你要看的物品不存在！\n");
		write("[返回:look]\n");
		return 1;	
	}
	string player_name = "";
	string ob_name = "";
	int ob_count = 0;
	int flag = 0;
	if(sscanf(arg,"%s %s %d",player_name,ob_name,ob_count) != 3){
		ob_name = arg;
		flag = 1;
		//write("无法查看物品！\n");
		//write("[返回:look]\n");
		//return 1;	
	}	
	object ob = 0;
	object player; 
	object me = this_player();
	if(me->query_name() == player_name)
		ob = present(ob_name,me,ob_count);
	else if(player_name != ""){
		player = find_player(player_name);
		if(player){
			ob = present(ob_name,player,ob_count);
		}
	}
	if(ob)
		this_player()->write_view(WAP_VIEWD["/inv_other"],ob,this_player());
	else if(flag){
		mixed err = catch{
			ob = (object)(ob_name);
		};
		if(ob && !err)
			this_player()->write_view(WAP_VIEWD["/inv_other"],ob,this_player());
		else{
			write("你要看的物品不存在！\n");
			write("[返回:look]\n");
			return 1;
		}
	}
	else{
		write("你要看的物品不存在！\n");
		write("[返回:look]\n");
		return 1;
	}
}
