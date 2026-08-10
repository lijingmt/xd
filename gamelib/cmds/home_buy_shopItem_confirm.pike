#include <command.h>
//#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	string masterId = "";
	int ignoredPrice = 0;
	int ignoredPriceFlag = 0;
	int shopId = 0;
	int ignoredTimeDelay = 0;
	string listingToken="";
	if(!arg || sscanf(arg,"%s %d %d %d %d %s",masterId,ignoredPrice,
	   ignoredPriceFlag,shopId,ignoredTimeDelay,listingToken)!=6 ||
	   masterId=="" || shopId<=0 || sizeof(listingToken)!=64){
		write("购买参数无效。\n[返回游戏:look]\n");
		return 1;
	}
	if(!LOGICALZONED->can_user_action("home",me->query_name(),masterId)){
		write("逻辑分区隔离中，不能购买该商店的物品。\n[返回游戏:look]\n");
		return 1;
	}
	mapping(string:mixed) result=HOMED->purchase_shop_listing(me,masterId,
		shopId,listingToken);
	if((int)result["ok"])
		s += "您成功购买了"+(string)result["item_name_cn"]+"\n";
	else
		s += (string)result["message"]+"\n";
	s += "\n\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
