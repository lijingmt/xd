#include <command.h>
#include <wapmud2/include/wapmud2.h>

private int can_bulk_buy(object item)
{
	if(!item || !item->is("combine_item"))
		return 0;
	return search(({"food","water","danyao"}),
		(string)item->query_item_type())!=-1;
}

private int inventory_amount(object player,string name)
{
	int amount=0;
	foreach(all_inventory(player),object item)
		if(item && item->query_name()==name)
			amount+=item->is("combine_item") ? (int)item->amount : 1;
	return amount;
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
		   count<1 || count>20){
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
		if(ob->is("combine_item"))
			ob->amount=count;
		string item_name=(string)ob->query_name();
		string item_name_cn=(string)ob->query_name_cn();
		if(me->if_over_load(ob)){
			MUD_SPEC_STORED->release_player_offer(me,offer_token);
			s = "你的背包已满，无法执行此操作，请返回。\n";       
			destruct(ob);
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}

		int need_money=fee*count;
		if(me->pay_money(need_money)==0){
			MUD_SPEC_STORED->release_player_offer(me,offer_token);
			s += "你身上的钱不够支付费用，请返回。\n";
			destruct(ob);
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		}
		else{
			int before=inventory_amount(me,item_name);
			mixed move_err=catch{
				if(ob->is("combine_item"))
					ob->move_player(me->query_name());
				else
					ob->move(me);
			};
			int added=inventory_amount(me,item_name)-before;
			if(move_err || added!=count){
				if(added>0)
					me->remove_combine_item_transaction(item_name,added);
				me->add_account(need_money);
				MUD_SPEC_STORED->release_player_offer(me,offer_token);
				if(ob)
					destruct(ob);
				s += "物品发放失败，费用已全部退回，请稍后重试。\n";
			}
			else if(!MUD_SPEC_STORED->consume_player_offer(
			        me,offer_token)){
				if(ob && environment(ob)==me)
					destruct(ob);
				else if(added>0)
					me->remove_combine_item_transaction(item_name,added);
				me->add_account(need_money);
				s += "货架状态已经变化，物品已回收且费用已退回。\n";
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
			s+="[返回游戏:look]\n";
			write(s);
		}
	}
	
	return 1;
}
