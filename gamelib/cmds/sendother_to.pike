#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	string s = "";
	string user_name;
	int user_count;
	string goods_id;
	object player=this_player();
	object goods;
	if(arg && sscanf(arg,"%s %s %d",user_name,goods_id,user_count)==3){
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
			//goods=present(goods_id,player,user_count); //[sb] is seller
			//查找玩家身上与name同名的非会员物品 added by caijie 080815
			goods=PLAYER_TRANSFERD->query_owned_item(player,goods_id,user_count);
			//add end
			if(goods&&goods->query_item_canSend()==0){
				s += "该物品不能赠送，请返回。\n";
				s += "[返回:look]\n";
				write(s);
				return 1;
			}
			else if(goods&&!goods->equiped){
				mapping(string:mixed) offer=PLAYER_TRANSFERD->create_gift_offer(
					player,ob,goods_id,user_count);
				if(!(int)offer["ok"]){
					s += (string)offer["message"]+"\n[返回:look]\n";
					write(s);
					return 1;
				}
				string token=(string)offer["token"];
				tell_object(ob,player->name_cn+"想赠送给你"+goods->query_short()+
					"\n[接受:sendother_ok "+player->name+" "+user_count+" "+
					goods->name+" "+token+" yes]\n[拒绝:sendother_ok "+
					player->name+" "+user_count+" "+goods->name+" "+token+
					" no]\n");
				s += "赠送请求已经发出，请等待对方确认接受。\n";
			}
			else{
				s += "你身上并没有要赠送的物品，或者该物品正在装备，无法赠送，请返回确认。\n";
			}
			s += "[返回:look]\n";
			write(s);
			return 1;
		}
	}
	s += "你要赠送什么东西给对方？\n";
	s += "[返回:look]\n";
	write(s);
	return 1;
}
