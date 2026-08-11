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

int main(string|zero arg)
{
	string name=arg;
	if(!name)
	{
		string s = "";
		s+= "没有这个物品\n";
		s+="[返回:list]\n";
		s+="[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(search(name,"..")!=-1 || name[0]=='/' ||
	   !is_current_store_item(this_player(),name)){
		write("该商品不在当前商店货架中。\n"+
			"[返回:list]\n[返回游戏:look]\n");
		return 1;
	}
	object ob=clone(ROOT+"/gamelib/clone/item/"+name);
	if(ob){
		string s=ob->query_name_cn()+"\n";
		s+=ob->query_picture_url()+"\n";
		if(ob->query_item_type()!="book")
			s+=ob->query_content? ob->query_content():"";
		s+=ob->query_desc();
		s+="[确定购买:buy_goods "+name+"]\n";
		if(can_bulk_buy(ob)){
			s+="批量购买（1—20）：[买5个:buy_goods "+name+" 5] "+
				"[买10个:buy_goods "+name+" 10] "+
				"[买20个:buy_goods "+name+" 20]\n";
			s+="[int no:...]\n";
			s+="[submit 自定义数量购买:buy_goods "+name+" ...]\n";
		}
		s+="[返回:list]\n";
		s+="[返回游戏:look]\n";
		write(s);
		destruct(ob);
	}
	else{
		string s = "";
		s+= "没有这个物品\n";
		s+="[返回:items]\n";
		s+="[返回游戏:look]\n";
		write(s);
	}
	return 1;
}
