#include <command.h>
//#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
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
	string moneyPath = "";
	sscanf(arg,"%s %d %d %d %d",masterId,price,priceFlag,shopId,timeDelay);
	if(priceFlag==1){
		tradeResult = BUYD->do_trade(me,price,0,1);
		moneyPath = "yushi/suiyu";
	}
	else{
		tradeResult = BUYD->do_trade(me,0,price,1);
		moneyPath = "money";
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
			object item;
			item = HOMED->get_shop_item(masterId,shopId);
			if(item){
				s += "您成功购买了"+item->query_name_cn()+"\n";
				HOMED->change_flag(masterId,shopId,2);//改变标志位
				if(item->is("combine_itme"))
					me->move_player(me->query_name());
				else
					item->move(me);
			}
			//记录店主的交易金额，用于销量排行
			price = (int)(price * (100-HOMED->get_tax(timeDelay))/100);
			object master;
			int remove_flag = 0;
			master = find_player(masterId);
			if(!master){
				me->load_player(masterId);
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
	s += "\n\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
