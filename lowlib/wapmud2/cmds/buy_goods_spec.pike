#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
#define MAX_BULK_BUY_COUNT 999

private int can_bulk_buy(object item)
{
	if(!item || !item->is("combine_item"))
		return 0;
	return search(({"food","water","danyao"}),
		(string)item->query_item_type())!=-1;
}

private string item_vip_owner(object item)
{
	if(item && functionp(item->query_toVip))
		return (string)item->query_toVip();
	return "";
}

private int inventory_amount(object player,string name,string vip_owner)
{
	int amount=0;
	foreach(all_inventory(player),object item)
		if(item && item->query_name()==name &&
		   item_vip_owner(item)==vip_owner)
			amount+=item->is("combine_item") ? (int)item->amount : 1;
	return amount;
}

private int bulk_capacity(object player,object item)
{
	array(object) items=all_inventory(player);
	string name=(string)item->query_name();
	string vip_owner=item_vip_owner(item);
	int stack_max=(int)item->max_count;
	int capacity=0;
	int free_slots;
	if(stack_max<1)
		return 0;
	foreach(items,object existing){
		if(!existing || !existing->is("combine_item") ||
		   existing->query_name()!=name ||
		   item_vip_owner(existing)!=vip_owner)
			continue;
		if((int)existing->amount>=0 && (int)existing->amount<stack_max)
			capacity+=stack_max-(int)existing->amount;
	}
	free_slots=player->query_beibao_size()-sizeof(items);
	if(free_slots>0)
		capacity+=free_slots*stack_max;
	return capacity;
}

private int deliver_combine_items(object player,string item_path,
	object first_item,int count)
{
	int remaining=count;
	int stack_max=(int)first_item->max_count;
	object|zero piece=first_item;
	if(stack_max<1)
		return 0;
	while(remaining>0){
		if(!piece){
			mixed clone_err=catch { piece=clone(item_path); };
			if(clone_err || !piece)
				return 0;
		}
		int chunk=remaining>stack_max ? stack_max : remaining;
		piece->amount=chunk;
		mixed move_err=catch {
			piece->move_player(player->query_name());
		};
		if(move_err || (piece && environment(piece)!=player)){
			if(piece)
				destruct(piece);
			return 0;
		}
		remaining-=chunk;
		piece=0;
	}
	return 1;
}

private int remove_inventory_amount(object player,string name,
	string vip_owner,int count)
{
	int remaining=count;
	foreach(all_inventory(player),object item){
		int available;
		int take;
		if(remaining<=0)
			break;
		if(!item || item->query_name()!=name ||
		   item_vip_owner(item)!=vip_owner)
			continue;
		available=item->is("combine_item") ? (int)item->amount : 1;
		if(available<=0)
			continue;
		take=available>remaining ? remaining : available;
		if(item->is("combine_item") && take<available)
			item->amount=available-take;
		else
			item->remove();
		remaining-=take;
	}
	return count-remaining;
}

private int parse_count(string|zero value)
{
	int count=1;
	if(!value || value=="")
		return count;
	if(sscanf(value,"no=%d",count)!=1 && sscanf(value,"%d",count)!=1)
		return 0;
	return count;
}

private void audit_suiyu_trade(object player,string item_name,int fee,
	string result,string offer_token)
{
	Stdio.append_file(ROOT+"/log/spec_shop_jade.log",sprintf(
		"%s user=%s item=%s fee=%d result=%s token=%s\n",
		ctime(time())[..sizeof(ctime(time()))-2],
		player ? (string)player->query_name() : "",item_name,fee,result,
		sizeof(offer_token)>=12 ? offer_token[..11] : offer_token));
}

int main(string|zero arg)
{
	string s = "";
	object ob,me = this_player();
	if(arg){
		string name="";
		string offer_token="";
		string count_value="";
		int supplied_fee=0;
		int parsed=sscanf(arg,"%s %d %s %s",name,supplied_fee,
			offer_token,count_value);
		// Pike 在缺少末尾可选字段时不会保留前一个 %s 的赋值：单件
		// 购买只有三段参数，必须用独立的三段格式重新解析报价凭证。
		if(parsed!=4){
			count_value="";
			parsed=sscanf(arg,"%s %d %s",name,supplied_fee,offer_token);
		}
		int count=parse_count(parsed==4 ? count_value : 0);
		if(parsed<3 || name=="" || search(name,"..")!=-1 ||
		   name[0]=='/' || sizeof(offer_token)!=64 ||
		   count<1 || count>MAX_BULK_BUY_COUNT){
			write("商品、价格或数量参数无效，本次没有扣款。\n"+
				"[返回游戏:look]\n");
			return 1;
		}
		mapping offer=MUD_SPEC_STORED->reserve_player_offer(
			me,name,offer_token);
		if(!sizeof(offer)){
			write("神秘货架已经刷新、过期或购买过，请重新刷新货架。\n"+
				"[返回:list_spec]\n[返回游戏:look]\n");
			return 1;
		}
		int fee=(int)offer["fee"];
		string currency=(string)offer["currency"];
		// supplied_fee只为旧书签参数兼容；真实价格和货币均来自服务端
		// token绑定报价，故意忽略客户端篡改值而不是拿它参与扣费。
		if(search(({"money","suiyu"}),currency)==-1){
			MUD_SPEC_STORED->release_player_offer(me,offer_token);
			write("货架报价校验失败，本次没有扣款，请重新刷新货架。\n"+
				"[返回:list_spec]\n[返回游戏:look]\n");
			return 1;
		}
		mixed clone_err=catch{
			ob=clone(ROOT+"/gamelib/clone/item/"+name);
		};
		if(!ob){
			MUD_SPEC_STORED->release_player_offer(me,offer_token);
			s += "你要购买的物品不存在，请返回。\n";	
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		if(count>1 && !can_bulk_buy(ob)){
			MUD_SPEC_STORED->release_player_offer(me,offer_token);
			s = "只有药品、食物和饮水可以批量购买；本商品仍需单件购买。\n";
			destruct(ob);
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		if(currency=="suiyu" && (count!=1 || ob->is("combine_item"))){
			MUD_SPEC_STORED->release_player_offer(me,offer_token);
			s = "碎玉装备报价仅允许单件购买，请重新刷新神秘货架。\n";
			destruct(ob);
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		string item_name=(string)ob->query_name();
		string item_name_cn=(string)ob->query_name_cn();
		string vip_owner=item_vip_owner(ob);
		int stackable=ob->is("combine_item");
		if((stackable && bulk_capacity(me,ob)<count) ||
		   (!stackable && me->if_over_load(ob))){
			MUD_SPEC_STORED->release_player_offer(me,offer_token);
			s = "你的背包已满，无法执行此操作，请返回。\n";       
			destruct(ob);
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}

		int need_amount=fee*count;
		int before_wallet=currency=="suiyu" ?
			ACCOUNT_WALLETD->query_balance(me) : 0;
		int before_physical=currency=="suiyu" ?
			YUSHID->query_physical_all_num(me) : 0;
		int paid=currency=="suiyu" ?
			YUSHID->pay_yushi(me,need_amount) : me->pay_money(need_amount);
		if(!paid){
			MUD_SPEC_STORED->release_player_offer(me,offer_token);
			s += currency=="suiyu" ?
				"你的碎玉不足，无法购买这件装备。\n" :
				"你身上的钱不够支付费用，请返回。\n";
			if(currency=="suiyu")
				audit_suiyu_trade(me,item_name,need_amount,"insufficient",
					offer_token);
			destruct(ob);
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		}
		else{
			int before=inventory_amount(me,item_name,vip_owner);
			int delivered=0;
			int delivery_saved=1;
			mixed move_err=catch{
				if(stackable){
					delivered=deliver_combine_items(me,
						ROOT+"/gamelib/clone/item/"+name,ob,count);
				}
				else{
					ob->move(me);
					delivered=1;
				}
			};
			int added=inventory_amount(me,item_name,vip_owner)-before;
			if(!move_err && delivered && added==count && currency=="suiyu")
				delivery_saved=me->save_with_result();
			if(move_err || !delivered || added!=count || !delivery_saved){
				int removed=0;
				if(added>0 && !stackable && ob && environment(ob)==me){
					ob->remove();
					removed=1;
				}
				else if(added>0)
					removed=remove_inventory_amount(me,item_name,
						vip_owner,added);
				int kept=added-removed;
				int refund=need_amount-fee*kept;
				int refunded=1;
				if(refund>0){
					if(currency=="suiyu")
						refunded=YUSHID->rollback_yushi_payment(me,
							before_wallet,before_physical,
							"spec_shop_equipment_delivery_failed");
					else
						me->add_account(refund);
				}
				if(currency=="suiyu" && refunded)
					refunded=me->save_with_result();
				if(kept>0)
					MUD_SPEC_STORED->consume_player_offer(me,offer_token);
				else
					MUD_SPEC_STORED->release_player_offer(me,offer_token);
				if(ob)
					destruct(ob);
				if(currency=="suiyu")
					audit_suiyu_trade(me,item_name,need_amount,
						kept>0 ? "delivery_failed_item_kept" :
						(refunded ? "delivery_failed_refunded" :
						 "delivery_failed_refund_error"),offer_token);
				if(kept>0)
					s += "批量发放中断，仅按背包中实际保留的"+
						kept+"件计费，其余费用已退回。\n";
				else if(!refunded)
					s += "物品发放和碎玉退款异常，请立即联系管理员。\n";
				else
					s += "物品发放失败，费用已全部退回，请稍后重试。\n";
			}
			else if(!MUD_SPEC_STORED->consume_player_offer(
			        me,offer_token)){
				int removed=0;
				if(added>0 && !stackable && ob && environment(ob)==me){
					ob->remove();
					removed=1;
				}
				else if(added>0)
					removed=remove_inventory_amount(me,item_name,
						vip_owner,added);
				int kept=added-removed;
				int refund=need_amount-fee*kept;
				int refunded=1;
				if(refund>0){
					if(currency=="suiyu")
						refunded=YUSHID->rollback_yushi_payment(me,
							before_wallet,before_physical,
							"spec_shop_offer_consume_failed");
					else
						me->add_account(refund);
				}
				if(currency=="suiyu" && refunded)
					refunded=me->save_with_result();
				if(currency=="suiyu")
					audit_suiyu_trade(me,item_name,need_amount,
						kept>0 ? "consume_failed_item_kept" :
						(refunded ? "consume_failed_refunded" :
						 "consume_failed_refund_error"),offer_token);
				if(kept>0)
					s += "货架状态已变化，仅按未能回收的"+
						kept+"件计费，其余费用已退回。\n";
				else if(!refunded)
					s += "货架状态变化且碎玉退款异常，请立即联系管理员。\n";
				else
					s += "货架状态已经变化，物品已回收且费用已退回。\n";
			}
			else{
				s += "交易成功！\n你花费"+
					(currency=="suiyu" ? (string)need_amount+"碎玉" :
					 MUD_MONEYD->query_store_money_cn(need_amount))+"\n";
				s += "得到了物品 "+count+"个"+item_name_cn+"！\n";
				string now=ctime(time());
				string tmp=now[0..sizeof(now)-2]+":"+me->name_cn+
					"("+me->name+")\n"+s;
				Stdio.append_file(ROOT+"/log/buy.log",tmp+"\n");
				if(currency=="suiyu")
					audit_suiyu_trade(me,item_name,need_amount,"success",
						offer_token);
			}
			s+="[返回游戏:look]\n";
			write(s);
		}
	}
	
	return 1;
}
