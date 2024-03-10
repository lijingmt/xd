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
	if(sscanf(arg,"%s %s %d",user_name,goods_id,user_count)==3){
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
			//goods=present(goods_id,player,user_count); //[sb] is seller
			//查找玩家身上与name同名的非会员物品 added by caijie 080815
			array(object) all_ob = all_inventory(player);
			foreach(all_ob,object each_ob){
				if(each_ob->query_name()==goods_id&&(!each_ob->query_toVip())){
					goods = each_ob;
					break;
				}
			}
			//add end
			if(goods&&goods->query_item_canSend()==0){
				s += "该物品不能赠送，请返回。\n";
				s += "[返回:look]\n";
				write(s);
				return 1;
			}
			else if(goods&&!goods->equiped){
				//sendother 
				tell_object(ob,player->name_cn+"想赠送给你"+goods->query_short()+"\n[接受:sendother_ok "+player->name+" "+user_count+" " +goods->name+" yes]\n[拒绝:sendother_ok "+player->name+" "+user_count+" "+goods->name+" no]\n");
				if(!player["/plus/sendrecd"])
					player["/plus/sendrecd"]= ([]);
				if(!player["/plus/sendrecd"][ob->name])
					player["/plus/sendrecd"][ob->name] = ([]);
				player["/plus/sendrecd"][ob->name][goods->name]++;
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
