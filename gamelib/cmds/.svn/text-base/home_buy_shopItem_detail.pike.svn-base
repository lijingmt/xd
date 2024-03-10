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
	string masterId = "";
	string itemName = "";
	int price = 0;
	int priceFlag = 0;//1：玉石 0：黄金
	int shopId = 0;
	int timeDelay = 0;
	sscanf(arg,"%s %d %d %d %d",masterId,price,priceFlag,shopId,timeDelay);
	object item = HOMED->get_shop_item(masterId,shopId);
	if(!item){
		s += "该摊位已经没有物品,请返回\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	s += env->query_name_cn()+"\n";
	s += item->query_name_cn()+"\n"+item->query_desc()+"\n";
	if(!item->is_combine_item()&&item->query_item_type()!="book"){
		s += item->query_content()+"\n"; 
	}
	s += "物品数量："+HOMED->get_shopItem_num(masterId,shopId)+"\n";
	s += "需要：";
	if(priceFlag==1){
		s += YUSHID->get_yushi_for_desc(price);
	}
	else{
		s += MUD_MONEYD->query_store_money_cn(price);
	}
	s += "\n\n";
	if(HOMED->is_master(homeId)){
		s += "[取消:home_shopItem_cancel "+shopId+" 0]\n";
	}
	else
		s += "[购买:home_buy_shopItem_confirm "+arg+"]\n";
	s += "[再逛一圈:popview]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
