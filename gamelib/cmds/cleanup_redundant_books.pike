#include <command.h>
#include <gamelib/include/gamelib.h>

#define REDUNDANT_BOOK_LOG ROOT "/log/redundant_book_cleanup.log"

string query_redundant_book_reject_reason(object player,object item)
{
	string kind;
	string type;
	string skill_name;
	int required_level;
	if(!player || !item || environment(item)!=player)
		return "not_in_backpack";
	if((string)item->query_item_type()!="book")
		return "not_book";
	if(item->query_item_canDrop()!=1 || item->query_item_canTrade()!=1 ||
	   item->query_item_canStorage()!=1 || item->query_toVip())
		return "restricted";
	if(item->query_item_task()==1 || item->query_item_only()==1 ||
	   (stringp(item->item_playerDesc) && item->item_playerDesc!="") ||
	   (string)item->query_item_from()!="")
		return "protected";
	if(functionp(item->query_account_bind_owner) &&
	   (string)item->query_account_bind_owner()!="")
		return "account_bound";
	kind=(string)item->query_peifang_kind();
	type=(string)item->query_peifang_type();
	if(kind!="" || type!=""){
		mapping learned;
		if(search(({"duanzao","liandan","caifeng","zhijia"}),kind)==-1 ||
		   type=="" || (int)item->peifang_id<0)
			return "invalid_recipe";
		learned=player["/"+kind+"/"+type];
		if(!mappingp(learned) || !(int)learned[(int)item->peifang_id])
			return "recipe_not_learned";
		return "";
	}
	skill_name=(string)item->skill_bname;
	if(skill_name=="" || !arrayp(player->skills[skill_name]))
		return "skill_not_learned";
	required_level=(int)item->skill_level;
	if(required_level<1)
		required_level=(int)item->beidong_level;
	if(required_level<1)
		required_level=1;
	if((int)player->skills[skill_name][0]<required_level)
		return "skill_level_needed";
	return "";
}

array(object) query_redundant_books(object player)
{
	array(object) result=({});
	if(!player)
		return result;
	foreach(all_inventory(player),object item)
		if(query_redundant_book_reject_reason(player,item)=="")
			result+=({item});
	return result;
}

mapping(string:mixed) perform_cleanup(object player)
{
	mapping(string:mixed) result=(["groups":0,"amount":0,"names":({})]);
	foreach(query_redundant_books(player),object item){
		string now;
		string path;
		string label;
		int amount;
		if(query_redundant_book_reject_reason(player,item)!="")
			continue;
		amount=item->is("combine_item") ? (int)item->amount : 1;
		if(amount<1)
			continue;
		path=(file_name(item)/"#")[0];
		label=(string)item->query_name_cn();
		result["groups"]=(int)result["groups"]+1;
		result["amount"]=(int)result["amount"]+amount;
		result["names"]+=({label+"×"+amount});
		now=ctime(time());
		Stdio.append_file(REDUNDANT_BOOK_LOG,
			now[..sizeof(now)-2]+" user="+player->query_name()+
			" item="+path+" amount="+amount+"\n");
		// 书本基类会在 read_flag==0 时把 remove() 解释成“学习一本”。
		// 清理命令的语义是玩家二次确认后删除整组，因此先收敛为单对象，
		// 也兼容极少数旧档案中断在 read_flag==0 的脏状态。
		if(item->is("combine_item"))
			item->amount=1;
		item->remove();
	}
	if((int)result["groups"]>0 && functionp(player->save_with_result))
		player->save_with_result();
	return result;
}

private string render_names(array names)
{
	string out="";
	int maximum=sizeof(names)>15 ? 15 : sizeof(names);
	for(int i=0;i<maximum;i++)
		out+="· "+names[i]+"\n";
	if(sizeof(names)>maximum)
		out+="· 另有"+(sizeof(names)-maximum)+"种\n";
	return out;
}

int main(string|zero arg)
{
	object player=this_player();
	array(object) candidates;
	mapping(string:mixed) result;
	mapping(string:int) grouped=([]);
	int amount;
	if(!player)
		return 1;
	if(player->in_combat){
		write("战斗中不能整理书卷。\n[返回游戏:look]\n");
		return 1;
	}
	if(arg=="confirm"){
		result=perform_cleanup(player);
		if(!(int)result["groups"])
			write("当前没有已经学会的重复技能书或配方。\n");
		else
			write("已清理"+(int)result["groups"]+"组，共"+
				(int)result["amount"]+"本重复书卷。\n"+
				render_names((array)result["names"]));
		write("[返回分类背包:inventory_filter]|[返回游戏:look]\n");
		return 1;
	}
	candidates=query_redundant_books(player);
	foreach(candidates,object item){
		int one=item->is("combine_item") ? (int)item->amount : 1;
		grouped[(string)item->query_name_cn()]=
			(int)grouped[(string)item->query_name_cn()]+one;
		amount+=one;
	}
	write("【清理已学重复书卷】\n");
	if(!sizeof(candidates)){
		write("当前没有已经学会的重复技能书或配方。\n"+
			"未学习、等级仍需要、账号绑定、任务、太古和受限书卷永久保留。\n"+
			"[返回分类背包:inventory_filter]|[返回游戏:look]\n");
		return 1;
	}
	array(string) names=({});
	foreach(sort(indices(grouped)),string name)
		names+=({name+"×"+(int)grouped[name]});
	write("将清理"+sizeof(candidates)+"组，共"+amount+
		"本你已经学会且不再需要的重复书卷：\n"+render_names(names));
	write("未学习、仍用于下一等级、账号绑定、任务、太古和受限书卷均不在候选中。\n"+
		"此操作不可恢复，不兑换金币。\n\n"+
		"[确认清理:cleanup_redundant_books confirm]\n"+
		"[取消:inventory_filter]|[返回游戏:look]\n");
	return 1;
}
