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

int main(string|zero arg)
{
	int money=0;
	int id=0;
	object me=this_player();
	string player_id;
	string receipt_id;
	mapping receipts;
	mapping(string:mixed) offer;
	if(!arg || sscanf(arg,"%d %d",money,id)!=2 || id<=0){
		write("领取参数无效。\n[返回:look]\n");
		return 1;
	}
	player_id=(string)me->query_name();
	receipt_id=(string)id;
	receipts=query_claim_receipts(me);
	if(receipts[receipt_id]=="money"){
		if(AUCTIOND->reconcile_getback_claim(player_id,id,"money")){
			m_delete(receipts,receipt_id);
			if(functionp(me->save_with_result))
				me->save_with_result();
			write("金钱已在账户中，本次已修复拍卖领取记录。\n[返回:look]\n");
		}
		else
			write("金钱已经安全入账，拍卖记录暂未完成，请稍后再试。\n[返回:look]\n");
		return 1;
	}
	offer=AUCTIOND->query_getback_offer(player_id,id,"money");
	if(!(int)offer["ok"] || (int)offer["money"]<=0 ||
	   (int)offer["money"]>2000000000){
		write("领取记录不存在、已经领取或金额异常。\n[返回:look]\n");
		return 1;
	}
	money=(int)offer["money"];
	mapping(string:mixed) prepared=AUCTIOND->prepare_getback_claim(
		player_id,id,"money",receipts[receipt_id]=="money");
	if(!(int)prepared["ok"]){
		if((string)prepared["code"]=="pending")
			write("这笔领取正在处理中，请稍后重试。\n[返回:look]\n");
		else
			write("无法领取：记录已变化或拍卖服务繁忙。\n[返回:look]\n");
		return 1;
	}
	if((int)prepared["saved_receipt"]){
		if(!AUCTIOND->complete_getback_claim(player_id,id,"money")){
			write("金钱已经安全入账，拍卖记录暂未完成，请稍后再次领取以修复记录。\n[返回:look]\n");
			return 1;
		}
		m_delete(receipts,receipt_id);
		if(functionp(me->save_with_result))
			me->save_with_result();
		write("金钱已在账户中，本次已修复拍卖领取记录。\n[返回:look]\n");
		return 1;
	}
	int before_money=me->query_account();
	me->add_account(money);
	receipts[receipt_id]="money";
	if(!functionp(me->save_with_result) || !me->save_with_result()){
		m_delete(receipts,receipt_id);
		me->del_account(me->query_account()-before_money);
		AUCTIOND->release_getback_claim(player_id,id,"money");
		write("人物存档失败，本次领取已经回滚。\n[返回:look]\n");
		return 1;
	}
	if(!AUCTIOND->complete_getback_claim(player_id,id,"money")){
		write("你已领取金钱，但拍卖记录暂未完成；请稍后再次领取以自动修复。\n[返回:look]\n");
		return 1;
	}
	m_delete(receipts,receipt_id);
	if(functionp(me->save_with_result))
		me->save_with_result();
	write("你领取了"+MUD_MONEYD->query_other_money_cn(money)+"\n[返回:look]\n");
	return 1;
}
