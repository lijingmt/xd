#include <command.h>
#include <wapmud2/include/wapmud2.h>

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
		string count_value="";
		int parsed=sscanf(arg,"%s %s",name,count_value);
		if(parsed<1)
			name=arg;
		int count=parse_count(parsed==2 ? count_value : 0);
		if(name=="" || search(name,"..")!=-1 || name[0]=='/' ||
		   count<1 || count>20 || !is_current_store_item(me,name)){
			write("商品或数量参数无效，购买数量必须在1到20之间。\n"+
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
		if(ob->is("combine_item"))
			ob->amount=count;
		string item_name=(string)ob->query_name();
		string item_name_cn=(string)ob->query_name_cn();
		if(me->if_over_load(ob)){
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
				if(ob)
					destruct(ob);
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
