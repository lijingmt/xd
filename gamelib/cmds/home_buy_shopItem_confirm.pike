#include <command.h>
//#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	object env = environment(me);
	string s = "";
	string masterId = "";
	string itemName = "";
	string s_log = "";
	int price = 0;
	int priceFlag = 0;//1：玉石 0：黄金
	int shopId = 0;
	int tradeResult = 0;
	int timeDelay = 0;
	int completed = 0;
	mapping(string:mixed) offer;
	object item;
	sscanf(arg,"%s %d %d %d %d",masterId,price,priceFlag,shopId,timeDelay);
	if(!LOGICALZONED->can_user_action("home",me->query_name(),masterId)){
		write("逻辑分区隔离中，不能购买该商店的物品。\n[返回游戏:look]\n");
		return 1;
	}
	offer = HOMED->query_shop_purchase_offer(masterId,shopId);
	if(!(int)offer["ok"]){
		write((string)offer["message"]+"\n[返回游戏:look]\n");
		return 1;
	}
	price = (int)offer["price"];
	priceFlag = (int)offer["price_flag"];
	timeDelay = (int)offer["time_delay"];
	item = HOMED->get_shop_item(masterId,shopId);
	if(!item){
		write("该摊位已经没有物品。\n[返回游戏:look]\n");
		return 1;
	}
	if(priceFlag==1){
		tradeResult = BUYD->do_trade(me,price,0,1);
	}
	else{
		tradeResult = BUYD->do_trade(me,0,price,1);
	}
	switch(tradeResult){
		case 0:
			s += "你身上的玉石不够！\n";
			break;
		case 1:
			s += "你身上的金钱不够！\n";
			break;
		case 2:
			s += "您的背包已满，不能再装下其它的东西\n";
			break;
		case 3:
			if(!HOMED->change_flag(masterId,shopId,2)){
				if(priceFlag==1)
					YUSHID->give_yushi(me,price);
				else
					me->add_account(price);
				destruct(item);
				s += "该物品刚刚已被购买，款项已经退回。\n";
				break;
			}
			s += "您成功购买了"+item->query_name_cn()+"\n";
			completed = 1;
			if(item->is("combine_item"))
				item->move_player(me->query_name());
			else
				item->move(me);
			//记录店主的交易金额，用于销量排行
			price = (int)(price * (100-HOMED->get_tax(timeDelay))/100);
			object master;
			int remove_flag = 0;
			master = find_player(masterId);
			if(!master){
				master = me->load_player(masterId);
				remove_flag = 1;
			}
			if(master){
				master->set_home_sale(priceFlag,price);
				if(remove_flag)
					master->remove();
			}
			break;
		default:
			s += "系统犯晕了，请和管理员联系。\n";
			break;
	}
	if(!completed && item)
		destruct(item);
	s += "\n\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
