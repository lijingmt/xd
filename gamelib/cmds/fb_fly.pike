#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	mapping(string:string) entry;
	int fee;
	if(!arg || arg==""){
		write("请选择要前往的幻境入口。\n");
		return 1;
	}
	if(me->query_in_combat()){
		write("交战中不能飞往幻境入口。\n");
		me->command("attack");
		return 1;
	}
	entry = FBD->query_safe_fb_entrance(arg);
	if(!sizeof(entry)){
		write("该幻境入口不存在或暂未开放，未扣除费用。\n");
		return 1;
	}
	fee = MAPD->query_player_fly_fee(me);
	if(fee>0 && me->pay_money(fee)==0){
		write("你身上的钱不够支付飞行费用"+
			MUD_MONEYD->query_store_money_cn(fee)+"。\n");
		return 1;
	}
	write("你支付了"+MUD_MONEYD->query_store_money_cn(fee)+
		"，飞往【幻境】"+(string)entry["name"]+"的安全入口。\n");
	me->command("qge74hye "+(string)entry["path"]);
	return 1;
}
