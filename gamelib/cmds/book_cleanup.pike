#include <command.h>
#include <gamelib/include/gamelib.h>
// 一键摧毁低级书卷（技能书/配方/图纸/卷轴/图样）：
// 只处理等级需求比人物当前等级低30级以上、可丢弃、非任务的
// 书本类物品；先预览再确认，高价值/职业不匹配的可交易书不碰。
#define BOOK_CLEANUP_LEVEL_GAP 30

private array(object) query_cleanup_books(object me)
{
	array(object) result=({});
	int my_level=(int)me->query_level();
	foreach(all_inventory(me),object ob){
		int level_limit;
		if(!ob || (string)ob->query_item_type()!="book")
			continue;
		if(!functionp(ob->query_item_task) ||
		   (int)ob->query_item_task()==1)
			continue;
		if(!functionp(ob->query_item_canDrop) ||
		   !(int)ob->query_item_canDrop())
			continue;
		if(!functionp(ob->query_item_canTrade) ||
		   !(int)ob->query_item_canTrade())
			continue;
		level_limit=(int)ob->level_limit;
		if(level_limit<=0 ||
		   level_limit+BOOK_CLEANUP_LEVEL_GAP>my_level)
			continue;
		result+=({ob});
	}
	return result;
}

int main(string|zero arg)
{
	object me=this_player();
	array(object) books;
	int count=0;
	int kinds=0;
	if(!me)
		return 1;
	if(me->in_combat){
		write("战斗中不能清理背包，请脱离战斗后再试。\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	if(arg!="confirm"){
		books=query_cleanup_books(me);
		if(!sizeof(books)){
			write("没有比当前等级低"+BOOK_CLEANUP_LEVEL_GAP+
				"级以上的可摧毁书卷。\n[返回游戏:look]\n");
			return 1;
		}
		write("【低级书卷清理】以下"+
			sizeof(books)+"组书卷可安全摧毁（需求等级低于你"+
			BOOK_CLEANUP_LEVEL_GAP+"级，任务书与可交易的近级书不包含）：\n");
		foreach(books,object ob){
			write("· "+ob->query_name_cn()+" ×"+(int)ob->amount+"\n");
			kinds++;
			if(kinds>=12 && sizeof(books)>12){
				write("· 另有"+(sizeof(books)-12)+"组\n");
				break;
			}
		}
		write("[确认摧毁:book_cleanup confirm]|[返回游戏:look]\n");
		return 1;
	}
	books=query_cleanup_books(me);
	foreach(books,object ob){
		count+=(int)ob->amount;
		destruct(ob);
	}
	write("【低级书卷清理】已摧毁"+sizeof(books)+"组共"+count+
		"本低级书卷。\n[返回游戏:look]\n");
	return 1;
}
