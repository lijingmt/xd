#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object player=this_player();
	mapping storage;
	int capacity;
	int price;
	int expected_capacity;
	if(!player)
		return 0;
	storage=ACCOUNT_STORAGED->query_storage(player);
	if(!(int)storage["ok"]){
		write((string)storage["message"]+"\n[返回共享仓库:account_storage]\n");
		return 1;
	}
	capacity=(int)storage["capacity"];
	price=ACCOUNT_STORAGED->query_capacity_expand_price(capacity);
	if(arg && sscanf(arg,"confirm %d",expected_capacity)==1){
		mapping result=ACCOUNT_STORAGED->purchase_capacity(
			player,expected_capacity);
		write((string)result["message"]+"\n");
		if((int)result["ok"])
			write("账号共享仓库已从"+(int)result["old_capacity"]+
				"格扩充到"+(int)result["capacity"]+"格。\n");
		write("[继续扩充:account_storage_expand]|"+
			"[返回共享仓库:account_storage]|[返回游戏:look]\n");
		return 1;
	}
	write("【账号共享仓库扩容】\n"+
		"当前容量："+capacity+"格；同一注册账号的所有职业共享。\n"+
		"每次永久增加"+ACCOUNT_STORAGED->query_capacity_expand_size()+
		"格，最高"+ACCOUNT_STORAGED->query_capacity_max()+"格。\n");
	if(price<=0)
		write("当前已经达到最大容量。\n");
	else
		write("本次需要"+YUSHID->get_yushi_for_desc(price)+"。\n\n"+
			"[确认购买20格:account_storage_expand confirm "+capacity+"]\n");
	write("[返回共享仓库:account_storage]|[返回游戏:look]\n");
	return 1;
}
