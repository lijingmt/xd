#include <command.h>
#include <gamelib/include/gamelib.h>

private mapping query_claim_receipts(object player)
{
	mapping receipts=player["/plus/auction_claim_receipts"];
	if(!mappingp(receipts)){
		receipts=([]);
		player["/plus/auction_claim_receipts"]=receipts;
	}
	return receipts;
}

private void rollback_items(array(object) items)
{
	foreach(items,object item)
		if(item)
			destruct(item);
}

private array(object) create_claim_items(object player,
	string goods_filename,int count,int convert_count)
{
	array(object) items=({});
	object sample;
	mixed err=catch{ sample=clone(goods_filename); };
	if(err || !sample)
		return ({});
	if(sample->is("combine_item")){
		int max_count=(int)sample->max_count;
		if(max_count<=0 || max_count>100000){
			destruct(sample);
			return ({});
		}
		int required_slots=(count+max_count-1)/max_count;
		if(required_slots>player->query_beibao_size() ||
		   sizeof(all_inventory(player))+required_slots>
		   player->query_beibao_size()){
			destruct(sample);
			return ({});
		}
		while(count>0){
			object item=sample;
			int one=count>max_count ? max_count : count;
			if(sizeof(items)>0){
				err=catch{ item=clone(goods_filename); };
				if(err || !item){
					rollback_items(items);
					return ({});
				}
			}
			item->amount=one;
			items+=({item});
			count-=one;
		}
		return items;
	}
	if(count!=1){
		destruct(sample);
		return ({});
	}
	if(sizeof(all_inventory(player))+1>player->query_beibao_size()){
		destruct(sample);
		return ({});
	}
	if(sample->is("equip") && convert_count)
		sample->set_convert_count(convert_count);
	return ({sample});
}

int main(string|zero arg)
{
	string goods_filename="";
	int count=1;
	int convert_count=0;
	int id=0;
	object me=this_player();
	string player_id;
	string receipt_id;
	mapping receipts;
	mapping(string:mixed) offer;
	array(object) rewards=({});
	if(!arg || sscanf(arg,"%s %d %d %d",goods_filename,count,
	   convert_count,id)!=4 || id<=0){
		write("领取参数无效。\n[返回:look]\n");
		return 1;
	}
	player_id=(string)me->query_name();
	receipt_id=(string)id;
	receipts=query_claim_receipts(me);
	if(receipts[receipt_id]=="item"){
		if(AUCTIOND->reconcile_getback_claim(player_id,id,"item")){
			m_delete(receipts,receipt_id);
			if(functionp(me->save_with_result))
				me->save_with_result();
			write("物品已在背包中，本次已修复拍卖领取记录。\n[返回:look]\n");
		}
		else
			write("物品已经安全入账，拍卖记录暂未完成，请稍后再试。\n[返回:look]\n");
		return 1;
	}
	offer=AUCTIOND->query_getback_offer(player_id,id,"item");
	if(!(int)offer["ok"]){
		write("无法领取：记录不属于你、已经领取或类型不符。\n[返回:look]\n");
		return 1;
	}
	goods_filename=(string)offer["goods"];
	count=(int)offer["count"];
	convert_count=(int)offer["convert_count"];
	if(!AUCTIOND->valid_getback_goods_path(goods_filename) ||
	   count<=0 || count>100000){
		write("领取记录内容异常，请联系管理员核对。\n[返回:look]\n");
		return 1;
	}
	if(receipts[receipt_id]!="item"){
		rewards=create_claim_items(me,goods_filename,count,convert_count);
		if(!sizeof(rewards)){
			write("无法领取！拍卖物品无法安全生成。\n[返回:look]\n");
			return 1;
		}
		if(sizeof(all_inventory(me))+sizeof(rewards)>
		   me->query_beibao_size()){
			rollback_items(rewards);
			write("对不起，您的背包空间不足，不能完整领取这些物品。\n[返回:look]\n");
			return 1;
		}
	}
	mapping(string:mixed) prepared=AUCTIOND->prepare_getback_claim(
		player_id,id,"item",receipts[receipt_id]=="item");
	if(!(int)prepared["ok"]){
		rollback_items(rewards);
		if((string)prepared["code"]=="pending")
			write("这笔领取正在处理中，请稍后重试。\n[返回:look]\n");
		else
			write("无法领取：记录已变化或拍卖服务繁忙。\n[返回:look]\n");
		return 1;
	}
	if((int)prepared["saved_receipt"]){
		rollback_items(rewards);
		if(!AUCTIOND->complete_getback_claim(player_id,id,"item")){
			write("物品已经安全入账，拍卖记录暂未完成，请稍后再次领取以修复记录。\n[返回:look]\n");
			return 1;
		}
		m_delete(receipts,receipt_id);
		if(functionp(me->save_with_result))
			me->save_with_result();
		write("物品已在背包中，本次已修复拍卖领取记录。\n[返回:look]\n");
		return 1;
	}
	int moved_ok=1;
	foreach(rewards,object reward){
		if(me->if_over_load(reward) || reward->move(me)!=1 ||
		   environment(reward)!=me){
			moved_ok=0;
			break;
		}
	}
	if(!moved_ok){
		rollback_items(rewards);
		AUCTIOND->release_getback_claim(player_id,id,"item");
		write("背包状态发生变化，本次没有领取物品。\n[返回:look]\n");
		return 1;
	}
	receipts[receipt_id]="item";
	if(!functionp(me->save_with_result) || !me->save_with_result()){
		m_delete(receipts,receipt_id);
		rollback_items(rewards);
		AUCTIOND->release_getback_claim(player_id,id,"item");
		write("人物存档失败，本次领取已经回滚。\n[返回:look]\n");
		return 1;
	}
	if(!AUCTIOND->complete_getback_claim(player_id,id,"item")){
		write("你已领取物品，但拍卖记录暂未完成；请稍后再次领取以自动修复。\n[返回:look]\n");
		return 1;
	}
	m_delete(receipts,receipt_id);
	if(functionp(me->save_with_result))
		me->save_with_result();
	write("你领取了拍卖物品，共 "+(string)count+" 件。\n[返回:look]\n");
	return 1;
}
