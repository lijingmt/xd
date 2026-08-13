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

int main(string|zero arg)
{
	string name;
	int fee;
	string offer_token;
	if(!arg){
		string s = "";
		s+= "没有这个物品\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(sscanf(arg,"%s %d %s",name,fee,offer_token)!=3 ||
	   !name || search(name,"..")!=-1 || name[0]=='/' ||
	   sizeof(offer_token)!=64){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,
			"商品参数无效，请重新刷新神秘货架。\n"+
			"[返回:list_spec]\n[返回游戏:look]\n");
		return 1;
	}
	mapping offer=MUD_SPEC_STORED->query_player_offer(
		this_player(),name,offer_token);
	if(!sizeof(offer)){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,
			"神秘货架已经刷新、过期或购买过，请重新刷新货架。\n"+
			"[返回:list_spec]\n[返回游戏:look]\n");
		return 1;
	}
	fee=(int)offer["fee"];
	object|zero ob;
	mixed clone_err=catch {
		ob=clone(ROOT+"/gamelib/clone/item/"+name);
	};
	if(ob){
		string s=ob->query_name_cn()+"\n";
		s+=ob->query_picture_url()+"\n";
		if(ob->query_item_type()!="book")
			s+=ob->query_content? ob->query_content():"";
		s+=ob->query_desc();
		s+="确定花费："+MUD_MONEYD->query_store_money_cn(fee)+"?\n";
		s+="[确定购买:buy_goods_spec "+name+" "+fee+" "+
			offer_token+"]\n";
		if(can_bulk_buy(ob)){
			s+="批量购买（1—"+MAX_BULK_BUY_COUNT+"）："+
				"[买50个:buy_goods_spec "+name+" "+fee+" "+offer_token+
				" 50] [买100个:buy_goods_spec "+name+" "+fee+" "+offer_token+
				" 100] [买300个:buy_goods_spec "+name+" "+fee+" "+offer_token+
				" 300] [买999个:buy_goods_spec "+name+" "+fee+" "+offer_token+
				" 999]\n";
			s+="[int no:...]\n";
			s+="[submit 自定义数量购买:buy_goods_spec "+name+" "+fee+
				" "+offer_token+" ...]\n";
		}
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		destruct(ob);
	}
	else{
		string s = "";
		s+= "没有这个物品\n";
		if(clone_err)
			s+= "商品数据暂时不可用，请重新刷新货架。\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	}
	return 1;
}
