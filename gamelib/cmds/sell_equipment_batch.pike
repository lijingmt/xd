#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	array(object) candidates;
	mapping result;
	int total_value = 0;
	if(!me)
		return 0;
	if(AUTOFIGHTD->query_vip_level(me)<1){
		write("一键安全卖装需要VIP1（水晶会员）。\n"+
			"[查看会员:vip_service_list]|[返回装备出售:inventory_sell]\n");
		return 1;
	}
	if(me->query_in_combat()){
		write("交战中不能批量出售装备，请脱离战斗后再试。\n"+
			"[返回战斗:flushview]\n");
		return 1;
	}
	if(AUTOFIGHTD->query_auto_sell_mode(me)=="off"){
		write("请先在智能清包中选择要出售的品质、类别和等级保护。\n"+
			"[设置智能清包:autofight cleanup]|"+
			"[返回装备出售:inventory_sell]\n");
		return 1;
	}
	candidates = AUTOFIGHTD->query_auto_sell_candidates(me);
	if(!sizeof(candidates)){
		write("当前没有符合安全规则的可出售装备；受保护物品不会被处理。\n"+
			"[调整清包规则:autofight cleanup]|"+
			"[返回装备出售:inventory_sell]\n");
		return 1;
	}
	foreach(candidates,object item)
		total_value += AUTOFIGHTD->query_auto_sell_value(item);
	if(arg!="confirm"){
		write("【一键安全卖装确认】\n\n"+
			"将按当前智能清包规则一次卖出"+sizeof(candidates)+
			"件装备，预计获得"+
			MUD_MONEYD->query_store_money_cn(total_value)+"。\n"+
			"已穿戴、任务、绑定、锻造、融合、镶嵌、特殊来源和珍贵装备不会进入候选。\n\n"+
			"[确认卖出:sell_equipment_batch confirm]|"+
			"[取消:inventory_sell]\n");
		return 1;
	}
	// 守护进程在真实执行前会逐件重新校验，避免确认后物品状态变化
	// 造成误卖；同一份事务接口也保证手动与挂机的保护规则完全一致。
	result = AUTOFIGHTD->perform_auto_sell(me);
	if((int)result["count"]<=0)
		write("装备状态已经变化，本次没有卖出任何物品。\n");
	else
		write("一键安全卖装完成：共卖出"+(int)result["count"]+
			"件，获得"+MUD_MONEYD->query_store_money_cn(
				(int)result["money"])+"。\n");
	write("[继续出售:inventory_sell]|[查看背包:inventory]|"+
		"[返回游戏:look]\n");
	return 1;
}
