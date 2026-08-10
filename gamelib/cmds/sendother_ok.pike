#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	string s = "";
	string user_name;
	int user_count;
	string goods_id;
	string offer_token;
	string type;
	object player=this_player();
	object goods;
	if(arg && sscanf(arg,"%s %d %s %s %s",user_name,user_count,goods_id,
	   offer_token,type)==5 &&
	   (type=="yes" || type=="no")){
		object ob=present(user_name,environment(player));
		if(!ob || ob==player || !PLAYER_TRANSFERD->same_local_room(player,ob)){
			s += "要赠送物品给你的人目前不在线，请返回。\n";
			s += "[返回:look]\n";
			write(s);
			return 1;
		}
		else if(!LOGICALZONED->can_interact(player,ob)){
			write("逻辑分区隔离中，该赠送请求已经失效。\n[返回:look]\n");
			return 1;
		}
		else{
			//goods=present(goods_id,ob,user_count); 
			//查找玩家身上与name同名的非会员物品 added by caijie 080815
			goods=PLAYER_TRANSFERD->query_owned_item(ob,goods_id,user_count);
			//add end
			if(goods){
				string goods_name_cn=(string)goods->name_cn;
				if(goods->equiped){
					s += "该物品正在装备，无法赠送，请返回确认。\n";
					s += "[返回游戏:look]\n";
					write(s);
					return 1;
				}
				else{
					if(type=="yes"){
						//判断身上物品是否超过60件
						mapping(string:mixed) transaction=
							PLAYER_TRANSFERD->execute_gift(player,ob,goods_id,
								user_count,offer_token);
						if(!(int)transaction["ok"]){
							s += (string)transaction["message"]+"\n";
							s += "[返回游戏:look]\n";
							write(s);
							return 1;
						}
						tell_object(player,"成功接受物品"+goods_name_cn+"\n");
						tell_object(ob,"物品"+goods_name_cn+"已经成功赠送给"+player->name_cn+"\n");
						s += "[返回游戏:look]\n";
						write(s);
						return 1;
					}
					else{
						PLAYER_TRANSFERD->cancel_gift_offer(offer_token,ob,player);
						tell_object(player,"你拒绝了"+ob->name_cn+"赠送给你的物品"+goods->name_cn+"\n");
						tell_object(ob,player->name_cn+"拒绝接受物品"+goods->name_cn+"\n");
						s += "[返回游戏:look]\n";
						write(s);
						return 1;
					}
				}
			}
			else
				s += "该物品不存在，请返回确认。\n";
		}
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
