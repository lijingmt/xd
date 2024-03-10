#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	int fee=0;
	object me = this_player();
	string s="";
	//先得到修理所有装备需要的金钱，提示用户是否需要一次性全部修理
	if(!arg){
		//先得到修理所有装备需要的金钱，提示用户是否需要一次性全部修理
		array(object) items=all_inventory(this_player());
		if(items&&sizeof(items)){
			for(int i=0;i<sizeof(items);i++){
				//得到每件装备的耐久并获得修理费用
				if(items[i]->equiped){
					if(items[i]->item_cur_dura != items[i]->item_dura){
						float a = (float)items[i]->query_item_canLevel();
						float b = (float)(items[i]->item_dura-items[i]->item_cur_dura)/(float)(items[i]->item_dura);
						float need = 0.00;
						need = ((a*50.00)/10.00)*b;
						int tmp = (int)need;
						if(tmp<=0)
							tmp = 1;
						fee += tmp;
					}
				}
			}
			if(fee){
				werror("\n-------repair all fee="+fee+"--------\n");
				s += "所有装备物品修理共需费用："+MUD_MONEYD->query_store_money_cn(fee)+"\n";
				s += "是否修理所有装备？\n";
				s += "[确定修理所有装备:repair_all ok]\n";
				s += "[我再考虑下:repair_all no]\n";
			}
			else
				s += "你所有装备的物品没有需要修理的，请返回。\n";
		}
		else
			s += "你没有可以修理的物品，请返回。\n";
	}
	else if(arg=="ok"){
		array(object) items=all_inventory(this_player());
		if(items&&sizeof(items)){
			for(int i=0;i<sizeof(items);i++){
				//得到每件装备的耐久并获得修理费用
				if(items[i]->equiped){
					if(items[i]->item_cur_dura != items[i]->item_dura){
						float a = (float)items[i]->query_item_canLevel();
						float b = (float)(items[i]->item_dura-items[i]->item_cur_dura)/(float)(items[i]->item_dura);
						float need = 0.00;
						need = (a*50.00)/10.00*b;
						
						int tmp = (int)need;
						if(tmp<=0)
							tmp = 1;
						fee += tmp;
						//fee += (int)need;
					}
				}
			}
		}
		if(me->pay_money(fee)==0)
			s += "你身上的钱不够支付修理所有装备的费用，请返回。\n";
		else{
			array(object) items=all_inventory(this_player());
			if(items&&sizeof(items)){
				for(int i=0;i<sizeof(items);i++){
					//每件装备的耐久恢复
					if(items[i]->equiped){
						if(items[i]->item_cur_dura != items[i]->item_dura)
							items[i]->item_cur_dura = items[i]->item_dura;
					}
				}
			}
			s += "修理结束，所有装备已经恢复了耐久度。\n";
			s += "此次修理共花费："+MUD_MONEYD->query_store_money_cn(fee)+"\n";
		}
	}
	else if(arg=="no")
		s += "想好了再来噢。\n";
	s += "[返回:look]\n";
	write(s);
	return 1;
}
