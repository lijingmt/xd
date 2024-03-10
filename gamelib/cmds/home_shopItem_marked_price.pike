#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string name ="";
	int count = 0;
	int timeDelay = 0;
	int shopId = 0;
	object env=environment(me);
	string s = "";
	object ob;
	sscanf(arg,"%s %d %d",name,shopId,timeDelay);
	array(object) all_ob = all_inventory(me);
	foreach(all_ob,object each_ob){
		if(each_ob->query_name()==name&&(!each_ob->query_toVip())){
			ob = each_ob;
			break;
		}
	}
	if(env){
		if(!ob)
			me->write_view(WAP_VIEWD["/emote"],0,0,"你身上没有那样东西。\n");
		else if(!ob->is("item"))
			me->write_view(WAP_VIEWD["/emote"],0,0,"该物品不属于可以出售的物品。\n");
		else if(ob->equiped)
			me->write_view(WAP_VIEWD["/emote"],0,0,"身上正在装备的东西无法出售。\n");
		else if(ob->query_item_save() == 0)
			me->write_view(WAP_VIEWD["/emote"],0,0,"此物品不能出售。\n");
		else if(!ob->query_item_canTrade())
			me->write_view(WAP_VIEWD["/emote"],0,0,"该类物品不能出售。\n");
		else if(ob->query_toVip())
			me->write_view(WAP_VIEWD["/emote"],0,0,"会员专属物品不能出售。\n");
		else if((ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor")&&ob->item_cur_dura<ob->item_dura)
			me->write_view(WAP_VIEWD["/emote"],0,0,"这破烂玩意不能出售，先拿去修修再来拍吧\n");
		else{
			s += "为您要出售的商品明码标价：\n";
			s += ob->query_name_cn()+"\n";
			int price = 0;
			if(ob->is("combine_item")){
				if(ob->query_item_type()=="food"||ob->query_item_type()=="water"||ob->query_item_type()==""){
					price = (ob->level_limit*50/4)*ob->amount;
				}
				else if(ob->query_for_material() != ""){
					price = ob->query_value()*ob->amount;
				}
			}
			else if(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor"||ob->query_item_type()=="decorate"||ob->query_item_type()=="jewelry"){
				price = ob->query_item_canLevel()*50/4;
			}
			if(price)
				s += "(市场价："+MUD_MONEYD->query_store_money_cn(price)+")\n";
			if(ob->is("combine_item")){
				s += "请输入您要出售的数量：\n";
				s += "[int nu:...]\n";
			}
			s += "请输入您所要出售的价格：\n";
			s += "[int xy:...]仙缘玉[int sy:...]碎玉\n";
			s += "或\n";
			s += "[int hj:...]金[int by:...]银\n";
			s += "[submit 确定:home_shopItem_marked_price_detail "+name+" "+shopId+" "+timeDelay+" ...]";
			s += "\n\n";
			s += "[服务中心:home_shop_service_center "+env->query_masterId()+"]\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
		}
	}
	return 1;
}
