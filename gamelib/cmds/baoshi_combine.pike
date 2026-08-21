#include <command.h>
#include <gamelib/include/gamelib.h>
// 宝石合成：三颗同名朴素宝石合成一颗对应闪亮宝石。同名堆叠归并后
// 判定数量；扣除、发放与存档同事务，存档失败整体回滚。

#define BAOSHI_COMBINE_COST 3

private int gem_amount(object player,string gem_name)
{
	int total=0;
	foreach(all_inventory(player),object item)
		if(item && (string)item->query_name()==gem_name &&
		   (string)item->query_item_type()=="baoshi")
			total+=(int)item->amount;
	return total;
}

private array(string) eligible_gem_names(object player)
{
	mapping(string:int) seen=([]);
	array(string) names=({});
	foreach(all_inventory(player),object item){
		string kind;
		if(!item || (string)item->query_item_type()!="baoshi" ||
		   !functionp(item->query_item_kind))
			continue;
		kind=(string)item->query_item_kind();
		if(kind!="pusu" || seen[(string)item->query_name()])
			continue;
		seen[(string)item->query_name()]=1;
		if(gem_amount(player,(string)item->query_name())>=
		   BAOSHI_COMBINE_COST)
			names+=({(string)item->query_name()});
	}
	return sort(names);
}

private int remove_gems(object player,string gem_name,int count)
{
	foreach(all_inventory(player),object item){
		if(!item || (string)item->query_name()!=gem_name ||
		   (string)item->query_item_type()!="baoshi" || count<1)
			continue;
		int have=(int)item->amount;
		if(have<=count){
			count-=have;
			item->amount=1;
			item->remove();
		}
		else{
			item->amount=have-count;
			count=0;
		}
		if(count<1)
			break;
	}
	return count<1;
}

int main(string|zero arg)
{
	object me=this_player();
	array(string) parts=arg ? (arg/" ")-({""}) : ({});
	string out="";
	if(!me)
		return 1;
	if(!sizeof(parts)){
		out="【宝石合成】三颗同名朴素宝石可合成一颗对应的闪亮宝石。\n";
		array(string) names=eligible_gem_names(me);
		if(!sizeof(names))
			out+="当前没有可合成的朴素宝石（每种至少需要"+
				BAOSHI_COMBINE_COST+"颗）。\n";
		foreach(names,string name)
			out+="[合成"+name+":baoshi_combine "+name+"]\n";
		out+="\n[返回游戏:look]\n";
		write(out);
		return 1;
	}
	string gem_name=parts[0];
	if(search(eligible_gem_names(me),gem_name)==-1){
		write("该宝石不足"+BAOSHI_COMBINE_COST+"颗，无法合成。\n"+
			"[返回宝石合成:baoshi_combine]\n[返回游戏:look]\n");
		return 1;
	}
	if(me->in_combat){
		write("战斗中不能合成宝石。\n[返回游戏:look]\n");
		return 1;
	}
	string target_name="sl"+gem_name[2..];
	object|zero target=0;
	mixed err=catch{
		target=clone(ITEM_PATH+"baoshi/"+target_name);
	};
	if(err || !target){
		write("合成目标宝石暂不可用，请稍后再试。\n"+
			"[返回宝石合成:baoshi_combine]\n[返回游戏:look]\n");
		return 1;
	}
	if(!remove_gems(me,gem_name,BAOSHI_COMBINE_COST)){
		destruct(target);
		write("宝石数量在合成中发生变化，已中止。\n"+
			"[返回宝石合成:baoshi_combine]\n[返回游戏:look]\n");
		return 1;
	}
	target->move(me);
	if(!me->save_with_result()){
		int restored=gem_amount(me,gem_name);
		destruct(target);
		// 回滚：先补回被扣除的三颗，再存档；补料失败则明确提示。
		object refund=clone(ITEM_PATH+"baoshi/"+gem_name);
		refund->amount=BAOSHI_COMBINE_COST;
		refund->move(me);
		if(!me->save_with_result())
			write("宝石合成存档失败且回滚异常，请立即联系管理员。\n");
		else
			write("宝石合成存档失败，材料已退回。\n");
		(void)restored;
		return 1;
	}
	write("合成成功：三颗"+gem_name+"化为一颗"+
		(string)target->query_name_cn()+"。\n"+
		"[继续合成:baoshi_combine]\n[返回游戏:look]\n");
	return 1;
}
