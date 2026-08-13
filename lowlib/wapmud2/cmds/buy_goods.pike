#include <command.h>
#include <wapmud2/include/wapmud2.h>
#define MAX_BULK_BUY_COUNT 999

private int can_bulk_buy(object item)
{
	if(!item || !item->is("combine_item"))
		return 0;
	return search(({"food","water","danyao"}),
		(string)item->query_item_type())!=-1;
}

private int is_current_store_item(object player,string item_name)
{
	object env=player ? environment(player) : 0;
	int low;
	int high;
	if(!env)
		return 0;
	low=(int)env->store_level_low;
	high=(int)env->store_level_high;
	return MUD_STORED->is_catalog_item(item_name,low,high);
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

// 一次大量购买会跨越多个30件堆叠。在扣款前同时计算已有
// 堆叠空位和剩余背包格，避免发到一半才发现背包已满。
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
		// 损坏档案中的负数堆叠不能被当成额外容量。
		if((int)existing->amount>=0 && (int)existing->amount<stack_max)
			capacity+=stack_max-(int)existing->amount;
	}
	free_slots=player->query_beibao_size()-sizeof(items);
	if(free_slots>0)
		capacity+=free_slots*stack_max;
	return capacity;
}

// move_player 会把单个对象截到 max_count，所以服务端按堆叠上限
// 分块发放。最终仍由调用方比对背包总增量。
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

// 回滚只匹配同物品名和同VIP归属的堆叠，不会误删另一归属的药品。
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

int main(string|zero arg)
{
	string s = "";
	object ob,me = this_player();
	if(arg){
		string name="";
		string count_value="";
		int parsed=sscanf(arg,"%s %s",name,count_value);
		if(parsed<1)
			name=arg;
		int count=parse_count(parsed==2 ? count_value : 0);
		if(name=="" || search(name,"..")!=-1 || name[0]=='/' ||
		   count<1 || count>MAX_BULK_BUY_COUNT ||
		   !is_current_store_item(me,name)){
			write("商品或数量参数无效，购买数量必须在1到999之间。\n"+
				"[返回:list]\n[返回游戏:look]\n");
			return 1;
		}
		mixed clone_err=catch{
			ob=clone(ROOT+"/gamelib/clone/item/"+name);
		};
		if(!ob){
			s += "你要购买的物品不存在，请返回。\n";	
			s+="[返回:list]\n";
			s+="[返回游戏:look]\n";
			write(s);
			return 1;
		}
		if(count>1 && !can_bulk_buy(ob)){
			s += "只有药品、食物和饮水可以批量购买；本商品仍需单件购买。\n";
			destruct(ob);
			s+="[返回:list]\n[返回游戏:look]\n";
			write(s);
			return 1;
		}
		string item_name=(string)ob->query_name();
		string item_name_cn=(string)ob->query_name_cn();
		string vip_owner=item_vip_owner(ob);
		int stackable=ob->is("combine_item");
		if((stackable && bulk_capacity(me,ob)<count) ||
		   (!stackable && me->if_over_load(ob))){
			string tmp = "你的背包已满，无法执行此操作，请返回。\n";       
			destruct(ob);
			tmp+="[返回:look]\n";
			write(tmp);
			return 1;
		}

		int unit_money = ob->query_item_canLevel ?
			(int)ob->query_item_canLevel()*50 : 10000*50;
		int need_money=unit_money*count;
		if(me->pay_money(need_money)==0)
			s += "你身上的钱不够支付费用，请返回。\n";
		else{
			int before=inventory_amount(me,item_name,vip_owner);
			int delivered=0;
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
			if(move_err || !delivered || added!=count){
				int removed=0;
				if(added>0 && !stackable && ob && environment(ob)==me){
					ob->remove();
					removed=1;
				}
				else if(added>0)
					removed=remove_inventory_amount(me,item_name,
						vip_owner,added);
				int kept=added-removed;
				int refund=need_money-unit_money*kept;
				if(refund>0)
					me->add_account(refund);
				if(ob)
					destruct(ob);
				if(kept>0)
					s += "批量发放中断，仅按背包中实际保留的"+
						kept+"件计费，其余费用已退回。\n";
				else
					s += "物品发放失败，费用已全部退回，请整理背包后重试。\n";
			}
			else{
				s += "交易成功！\n你花费"+
					MUD_MONEYD->query_store_money_cn(need_money)+"\n";
				s += "得到了物品 "+count+"个"+item_name_cn+"！\n";
				string now=ctime(time());
				string tmp=now[0..sizeof(now)-2]+":"+me->name_cn+
					"("+me->name+")\n"+s;
				Stdio.append_file(ROOT+"/log/buy.log",tmp+"\n");
			}
		}
		if(ob && environment(ob)!=me)
			destruct(ob);
	}
	s+="[返回:list]\n";
	s+="[返回游戏:look]\n";
	write(s);
	return 1;
}
