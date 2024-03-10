#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	//string s="你要寄卖什么物品？\n";
	object me = this_player();
	int shopId = (int)arg;
	string list = "home_shop";
	//this_player()->write_view(WAP_VIEWD["/home_add_daoju_shopItem"]);
	mapping(string:int) name_count=([]);
	array(object) items=all_inventory(me);
	string out="请选择您要出售的物品\n";
	string out_no_equip="";
	int count_max = me->query_beibao_size();//用户背包的实际容量（包括扩充后的）
	if(items&&sizeof(items)){
		out+="(物品："+sizeof(items)+"/"+count_max+")\n";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())&&items[i]->query_item_type()!="yushi"){
				//道具-装备物品不做处理
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry")
				inv_count++;
				//道具-可食用物品
				else if(items[i]->query_item_type()=="food"||items[i]->query_item_type()=="water"){
					out_no_equip+="["+items[i]->query_short();
					out_no_equip+="("+MUD_MONEYD->query_store_money_cn((items[i]->level_limit*50/4)*items[i]->amount)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//作为锻造，炼金原材料的物品出售,价格=value*amount
				else if(items[i]->is("combine_item") && items[i]->query_for_material() != ""){
					out_no_equip+="["+items[i]->query_short();
					out_no_equip+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_value()*items[i]->amount)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//道具-一般物品：任务物品和特殊物品等,无价格显示
				else{
					//不可买卖的，不予显示,可以买卖的，根据策划定义价格关键运算属性来得到价格
					if(!items[i]->query_item_task()){
						out_no_equip+="["+items[i]->query_short();
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
						name_count[items[i]->query_name()]++;
						daoju_count++;
					}
				}
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(list=="home_shop"){
			if(inv_count)
				howitem += "[装备("+inv_count+"):home_add_shopItem "+arg+"]";
			else
				howitem += "装备("+inv_count+")";
			if(daoju_count)
				howdaoju += "[道具("+daoju_count+"):home_add_daoju_shopItem "+arg+"]";
			else
				howdaoju += "道具("+daoju_count+")";
		}
			out += howitem + " " + howdaoju+"\n";	
	}
	if(out_no_equip==""){
		out += "您身上没有可以出售的道具\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,out+out_no_equip);
	return 1;
}
