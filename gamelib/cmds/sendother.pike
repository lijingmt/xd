#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	string user_name;
	int user_count;
	string goods_id;
	string type;
	object player=this_player();
	object goods;
	if(sscanf(arg,"%s",user_name)==1){
		object ob=present(user_name,environment(player));
		if(!ob)
	    		ob=find_player(user_name);
		if(!ob){
			s += "你要赠送物品的人不在这里，请返回。\n";	
			s += "[返回:look]\n";
			write(s);
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
	return 1;
}
