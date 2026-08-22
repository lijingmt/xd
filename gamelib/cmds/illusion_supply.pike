#include <command.h>
#include <gamelib/include/gamelib.h>
// 幻境补给：S1世界没有武器店与药铺，补一个自助补给点——
// 按瓶购买新手红药/凝神露（挂机可自动饮用），并支持一键修理全部装备。
// 只对S1激活人物开放，价格仅为轻微金钱回收，不引入新经济。

#define POTION_RED ROOT "/gamelib/clone/item/food/xinshouhongyao"
#define POTION_BLUE ROOT "/gamelib/clone/item/water/xinshoulanyao"
#define POTION_PRICE 20

private int query_repair_fee(object me)
{
	int fee=0;
	foreach(all_inventory(me),object item){
		if(item && item->equiped &&
		   item->item_cur_dura!=item->item_dura){
			float a=(float)item->query_item_canLevel();
			float b=(float)(item->item_dura-item->item_cur_dura)/
				(float)item->item_dura;
			int need=(int)(((a*50.00)/10.00)*b);
			if(need<=0)
				need=1;
			fee+=need;
		}
	}
	return fee;
}

private int grant_potion(object me,string path,int count)
{
	object item;
	mixed err;
	if(!me || count<=0)
		return 0;
	err=catch{ item=clone(path); };
	if(err || !item)
		return 0;
	item->amount=count;
	if(me->if_over_load(item)){
		destruct(item);
		return 0;
	}
	err=catch{ item->move_player(me->query_name()); };
	if(err){
		if(item)
			destruct(item);
		return 0;
	}
	return 1;
}

int main(string|zero arg)
{
	object me=this_player();
	string action=arg ? arg : "";
	string s="";
	int count;
	if(!me)
		return 1;
	if(PERSONAL_DIFFICULTYD->query_scope(me)!="S1"){
		write("幻境补给只对新月幻境中的行者开放。\n[返回游戏:look]\n");
		return 1;
	}
	if(action==""){
		s="【幻境补给】新月原野上的流动商队。\n";
		s+="新手红药（恢复生命，挂机自动饮用）："+POTION_PRICE+"文/瓶\n";
		s+="新手凝神露（恢复法力，挂机自动饮用）："+POTION_PRICE+"文/瓶\n";
		s+="[买红药10瓶:illusion_supply red 10]|[买红药50瓶:illusion_supply red 50]\n";
		s+="[买凝神露10瓶:illusion_supply blue 10]|[买凝神露50瓶:illusion_supply blue 50]\n";
		s+="[修理全部装备:illusion_supply repair]\n";
		s+="[返回幻境任务:illusion_realm]|[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(action=="repair"){
		int fee=query_repair_fee(me);
		if(fee<=0){
			write("你的装备都完好无损。\n[返回:illusion_supply]\n");
			return 1;
		}
		if(me->pay_money(fee)==0){
			write("你身上的钱不够支付修理费用（需要"+
				MUD_MONEYD->query_store_money_cn(fee)+"）。\n"+
				"[返回:illusion_supply]\n");
			return 1;
		}
		foreach(all_inventory(me),object item)
			if(item && item->equiped &&
			   item->item_cur_dura!=item->item_dura)
				item->item_cur_dura=item->item_dura;
		write("修理结束，所有装备恢复耐久，花费"+
			MUD_MONEYD->query_store_money_cn(fee)+"。\n"+
			"[返回:illusion_supply]\n");
		return 1;
	}
	if(sscanf(action,"%s %d",action,count)==2 &&
	   (action=="red" || action=="blue") &&
	   (count==10 || count==50)){
		int cost=count*POTION_PRICE;
		if(me->pay_money(cost)==0){
			write("你身上的钱不够（需要"+
				MUD_MONEYD->query_store_money_cn(cost)+"）。\n"+
				"[返回:illusion_supply]\n");
			return 1;
		}
		if(!grant_potion(me,
		   action=="red" ? POTION_RED : POTION_BLUE,count)){
			me->add_money(cost);
			write("背包空间不足，货款已退回。\n[返回:illusion_supply]\n");
			return 1;
		}
		if(action=="red")
			me["/plus/autofight_food"]="xinshouhongyao";
		else
			me["/plus/autofight_water"]="xinshoulanyao";
		write("购买成功，花费"+MUD_MONEYD->query_store_money_cn(cost)+
			"。\n[继续补给:illusion_supply]\n[返回游戏:look]\n");
		return 1;
	}
	write("补给参数无效。\n[返回:illusion_supply]\n");
	return 1;
}
