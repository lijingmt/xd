#include <command.h>
#include <gamelib/include/gamelib.h>
// 帮贡商店兑换：bang_shop_buy <item_id> <count>
int main(string|zero arg)
{
	object me = this_player();
	string item_id = "";
	int count = 1;
	mapping result;
	if(!me)
		return 0;
	if(!arg || sscanf(arg,"%s %d",item_id,count)!=2)
		item_id = arg ? arg : "";
	if(item_id==""){
		write("请指定要兑换的物品。\n[返回帮贡商店:bang_shop]\n");
		return 1;
	}
	result = BANGPAI_EXTD->buy_bang_shop_item(me,item_id,count);
	if(!(int)result["ok"]){
		write((string)result["message"]+"\n"+
			"[返回帮贡商店:bang_shop]\n");
		return 1;
	}
	write("兑换成功，获得"+(string)(int)result["granted"]+"件。"+
		((int)result["refunded"] ? "背包空间不足，未发出的部分已退还帮贡。" : "")+
		"\n[继续兑换:bang_shop]\n");
	return 1;
}
