#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	string s = "";
	string user_name;
	object player=this_player();
	if(arg && sscanf(arg,"%s",user_name)==1){
		object ob=present(user_name,environment(player));
		if(!ob || ob==player || !PLAYER_TRANSFERD->same_local_room(player,ob)){
			s += "你要赠送物品的人不在这里，请返回。\n";	
			s += "[返回:look]\n";
			write(s);
			return 1;
		}
		else if(!LOGICALZONED->can_interact(player,ob)){
			write("逻辑分区隔离中，无法向该玩家赠送物品。\n[返回:look]\n");
			return 1;
		}
		else{
			arg="sendother_to "+arg;
			this_player()->write_view(WAP_VIEWD["/inventory_send_item"],ob,0,arg);
			return 1;
		}
	}
	s += "你要赠送物品给谁？\n";	
	s += "[返回:look]\n";
	write(s);
	return 1;
}
