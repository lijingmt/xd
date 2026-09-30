#include <command.h>
#include <gamelib/include/gamelib.h>
// 角色仓库批量卖装（2026-09-30 玩家反馈"仓库爆了，卖着费劲"）：
// 逐行恢复→按智能清包规则校验→立即回仓做预览；确认后再恢复→
// 逐件重校验→销毁换银两。保护规则与一键安全卖装完全一致
// （已穿戴/任务/绑定/锻造/融合/镶嵌/特殊来源不进候选），
// VIP门槛也一致（VIP1）。
#define AUTOFIGHT_D ((object)(ROOT "/gamelib/single/daemons/autofightd.pike"))
#define ASYNC_IOD ((object)(ROOT "/gamelib/single/daemons/async_iod.pike"))
#define PERSONAL_STORAGE_SELL_LOG ROOT "/log/personal_storage_sell.log"

private array(array) sell_snapshot_rows(object player)
{
	array(array) rows=({});
	if(!arrayp(player->packaged_items))
		return rows;
	foreach(player->packaged_items,array row)
		if(arrayp(row) && sizeof(row)>=8 && stringp(row[7]) &&
		   sizeof((string)row[7])==64)
			rows+=({row});
	return rows;
}

private object sell_restore_row(object player,string sid)
{
	object ob=player->repackaged_by_storage_id(sid);
	if(!ob)
		return 0;
	if(ob->is("combine_item"))
		ob->move_player(player->query_name());
	else
		ob->move(player);
	return ob;
}

/** 预览评估：恢复全部可卖装备行并立即回仓（仓库净零容量）。 */
mapping query_storage_sell_state(object player)
{
	array(mapping) candidates=({});
	array(string) leftover=({});
	foreach(sell_snapshot_rows(player),array row){
		object ob=sell_restore_row(player,(string)row[7]);
		if(!ob)
			continue;
		int sellable=0;
		if(environment(ob)==player && ob->is("equip") &&
		   AUTOFIGHT_D->query_auto_sell_reject_reason(player,ob)=="")
			sellable=1;
		if(sellable)
			candidates+=({([
				"name":(string)ob->query_name_cn(),
				"value":AUTOFIGHT_D->query_auto_sell_value(ob),
			])});
		// packaged()只写快照行不销毁原对象；回仓成功必须destruct，
		// 否则背包残留实体在后续存仓时被反复快照（仓库行数滚雪球）。
		if(player->packaged(ob,player->query_cangku_size()))
			leftover+=({(string)ob->query_name_cn()});
		else
			destruct(ob);
	}
	// 回仓重建行会丢第8列永久ID，补齐后确认阶段才能按ID找到行。
	ACCOUNT_STORAGED->query_storage(player);
	return (["candidates":candidates,"leftover":leftover]);
}

/** 执行：逐行恢复重校验后销毁换银两。 */
mapping perform_storage_sell(object player)
{
	mapping(string:mixed) result=(["count":0,"money":0]);
	if(!player || player->query_in_combat())
		return result;
	foreach(sell_snapshot_rows(player),array row){
		object ob=sell_restore_row(player,(string)row[7]);
		if(!ob || environment(ob)!=player || !ob->is("equip") ||
		   AUTOFIGHT_D->query_auto_sell_reject_reason(player,ob)!=""){
			// 不卖件必须原样回仓并销毁背包实体（快照+实体并存
			// 会在后续存仓时翻倍）。
			if(ob){
				if(player->packaged(ob,player->query_cangku_size()))
					continue;
				destruct(ob);
			}
			continue;
		}
		string name=(string)ob->query_name_cn();
		int value=AUTOFIGHT_D->query_auto_sell_value(ob);
		mixed remove_err=catch{ ob->remove(); };
		if(remove_err || ob)
			continue;
		player->add_money(value);
		result["count"]=(int)result["count"]+1;
		result["money"]=(int)result["money"]+value;
		ASYNC_IOD->append_log(PERSONAL_STORAGE_SELL_LOG,
			MUD_TIMESD->get_mysql_timedesc()+" user="+
			(string)player->query_name()+" item="+
			replace(name,(["\n":" ","\r":" "]))+
			" money="+(string)value+"\n");
	}
	return result;
}

int main(string|zero arg)
{
	object me=this_player();
	if(!me)
		return 0;
	if(me->query_in_combat()){
		write("交战中不能批量出售，请脱离战斗后再试。\n"+
			"[返回战斗:flushview]\n");
		return 1;
	}
	if(AUTOFIGHT_D->query_vip_level(me)<1){
		write("仓库批量卖装需要VIP1（水晶会员）。\n"+
			"[查看会员:vip_service_list]|"+
			"[返回仓库:personal_storage]\n");
		return 1;
	}
	if(AUTOFIGHT_D->query_auto_sell_mode(me)=="off"){
		write("请先在智能清包中选择要出售的品质、类别和等级保护，"+
			"仓库卖装与背包卖装使用同一套安全规则。\n"+
			"[设置智能清包:autofight cleanup]|"+
			"[返回仓库:personal_storage]\n");
		return 1;
	}
	if(me->if_over_easy_load && me->if_over_easy_load()){
		write("背包已满。仓库卖装需要临时取出评估，"+
			"请先清出背包空间再试。\n[返回仓库:personal_storage]\n");
		return 1;
	}
	mapping state=query_storage_sell_state(me);
	array(mapping) candidates=(array)state["candidates"];
	int total_value=0;
	foreach(candidates,mapping cand)
		total_value+=(int)cand["value"];
	if(arg!="confirm"){
		string s="§g【角色仓库·批量卖装】§r\n"+
			"按当前智能清包规则，角色仓库中可安全出售"+
			sizeof(candidates)+"件装备，预计获得"+
			MUD_MONEYD->query_store_money_cn(total_value)+
			"。\n已穿戴、任务、绑定、锻造、融合、镶嵌、特殊来源"+
			"和珍贵装备不会进入候选。\n";
		if(sizeof((array)state["leftover"]))
			s+="⚠ 有"+sizeof((array)state["leftover"])+
				"件评估后未能回仓，已留在背包。\n";
		if(!sizeof(candidates))
			s+="没有符合条件的可出售装备。\n";
		s+="\n";
		if(sizeof(candidates))
			s+="[确认批量卖出:personal_storage_sell confirm]\n";
		s+="[设置清包规则:autofight cleanup]|"+
			"[返回仓库:personal_storage]|[返回游戏:look]\n";
		write(s);
		return 1;
	}
	mapping done=perform_storage_sell(me);
	if((int)done["count"]<=0){
		write("仓库装备状态变化，本次没有卖出任何物品。\n"+
			"[返回仓库:personal_storage]\n");
		return 1;
	}
	if(functionp(me->save_with_result) && !me->save_with_result()){
		write("⚠ 存档失败，请重新登录确认银两与仓库。\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	write("【仓库批量卖装】共卖出"+(int)done["count"]+
		"件，获得"+MUD_MONEYD->query_store_money_cn(
			(int)done["money"])+"。\n"+
		"[再次评估:personal_storage_sell]|"+
		"[返回仓库:personal_storage]|[返回游戏:look]\n");
	return 1;
}
