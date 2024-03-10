#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	if(!name)
	{
		string s = "";
		s+= "没有这个物品\n";
		s+="[返回:list]\n";
		s+="[返回游戏:look]\n";
		write(s);
	}
	object ob=clone(ROOT+"/gamelib/clone/item/"+name);
	if(ob){
		string s=ob->query_name_cn()+"\n";
		s+=ob->query_picture_url()+"\n";
		if(ob->query_item_type()!="book")
			s+=ob->query_content();
		s+=ob->query_desc();
		s+="[确定购买:buy_goods "+name+"]\n";
		//s+="输入你想一次购买"+ob->query_name_cn()+"的数目（范围一到五十）[int:buy_lots_goods "+name+" ...]\n";
		s+="[返回:list]\n";
		s+="[返回游戏:look]\n";
		write(s);
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
