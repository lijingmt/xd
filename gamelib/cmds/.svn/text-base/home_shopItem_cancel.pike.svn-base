#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>

//服务中心
int main(string arg)
{
	object me = this_player();
	object env = environment(me);
	string s = "";
	string homeId = env->query_homeId();
	string masterId = me->query_name();
	string itemName = "";
	int price = 0;
	int shopId = 0;
	int timeDelay = 0;
	int flag = 0;
	sscanf(arg,"%d %d",shopId,flag);
	object item = HOMED->get_shop_item(masterId,shopId);
	if(HOMED->is_master(homeId)){
		if(item){
			if(flag==0){
				s += "您确定取消出售"+item->query_name_cn()+"么？\n";
				s += "[确定:home_shopItem_cancel "+shopId+" 1] [放弃:look]\n";
			}
			else{
				string itemNameCn = item->query_name_cn();
				if(item->is("combine_item")){
					item->move_player(masterId);
				}
				else {
					item->move(me);
				}
				s += "取消成功，"+itemNameCn+"已经放到你的背包里";
				HOMED->save_shopItem(masterId,"",shopId);
			}
		}
		else{
			s += "物品不存在，请返回\n";
		}
	}
	else {
		s += "你不是这家的主人，不能进行此项操作\n";
		s += "[返回:popview]\n";
	}
	s += "\n\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
