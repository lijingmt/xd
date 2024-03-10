#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string name ="";
	int timeDelay = 0;
	string s_xy = "";
	string s_sy = "";
	string s_hj = "";
	string s_by = "";
	int xianyu = 0;
	int suiyu = 0;
	int jin = 0;
	int yin = 0;
	int price = 0;
	int ind = 0; //摊位
	int count = -1;//出售的数量。针对绑定物品
	int all_amount = 0;
	string s_count = "";
	object env=environment(me);
	object ob ;
	string s = "";
//	werror("-----arg="+arg+"--\n");
	if(sscanf(arg,"%s %d %d %s %s %s %s %s",name,ind,timeDelay,s_count,s_hj,s_by,s_sy,s_xy)==8){
//	werror("-----s_count="+s_count+"---s_hj="+s_hj+"s_by="+s_by+"s_sy="+s_sy+"s_xy="+s_xy+"--\n");
		sscanf(s_count,"nu=%d",count);
		sscanf(s_xy,"xy=%d",xianyu);
		sscanf(s_sy,"sy=%d",suiyu);
		sscanf(s_hj,"hj=%d",jin);
		sscanf(s_by,"by=%d",yin);
	}
	else{
		sscanf(arg,"%s %d %d %s %s %s %s",name,ind,timeDelay,s_hj,s_by,s_sy,s_xy);
		sscanf(s_xy,"xy=%d",xianyu);
		sscanf(s_sy,"sy=%d",suiyu);
		sscanf(s_hj,"hj=%d",jin);
		sscanf(s_by,"by=%d",yin);
	}
	array(object) all_ob = all_inventory(me);
	foreach(all_ob,object each_ob){
		if(each_ob->query_name()==name&&(!each_ob->query_toVip())){
			if(each_ob->is("combine_item")){
				all_amount += each_ob->amount;
				ob = each_ob;
			}
			else{
				ob = each_ob;
				count = 1;
				break;
			}
		}
	}
	if(env && ob){
		if(ob->is("combine_item")){
			//判断是否足够
			if(count>20||count<1){
				s += "输入出售数量有误，出售数量必须在1～20之间\n";
				s += "[重新输入:home_shopItem_marked_price "+name+" "+ind+" "+timeDelay+"]\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			else if(count>all_amount){
				s += "你输入的数量大于你拥有的"+ob->query_name_cn()+"的数量,请正确输入\n";
				s += "[重新输入:home_shopItem_marked_price "+name+" "+ind+" "+timeDelay+"]\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
		}
		//以玉标码,可以标价
		if(xianyu!=0||suiyu!=0){
			if(jin!=0||yin!=0){
				s += "价格只能为玉或金，请正确输入\n";
				s += "[重新标价:home_shopItem_marked_price "+name+" "+ind+" "+timeDelay+"]\n";
			}
			else{
				price = xianyu*10+suiyu;
				s += "您将以"+YUSHID->get_yushi_for_desc(price)+"出售"+ob->query_name_cn()+"期限为"+timeDelay+"天，交易成功后征收"+HOMED->get_tax(timeDelay)+"%所得税\n";
				//s += "您将以"+YUSHID->get_yushi_for_desc(price)+"出售"+count+ ob->unit +ob->query_name_cn()+"期限为"+timeDelay+"天，交易成功后征收"+HOMED->get_tax(timeDelay)+"%所得税\n";
				s += "您确定出售吗？\n";
				s += "[确定:home_shopItem_marked_price_confirm 1 "+name+" "+count+" "+timeDelay+" "+price+" "+ind+"]\n";
				s += "[我再想想:home_myzone]\n";
			}
		}
		else{
			if(jin==0&&yin==0){
				s += "您把该物品的价格设置为0，这可是相当于免费赠送啊~您确定要这么做吗？\n";
				s += "[确定:home_shopItem_marked_price_confirm 0 "+name+" "+count+" "+timeDelay+" "+price+" "+ind+"]\n";
				s += "[重新标价:home_shopItem_marked_price "+name+" "+ind+" "+timeDelay+"]\n";
			}
			else{
				price = jin*100+yin;
				s += "您将以"+jin+"金"+yin+"银出售"+count+ ob->unit +ob->query_name_cn()+"期限为"+timeDelay+"天，交易成功后征收"+HOMED->get_tax(timeDelay)+"%所得税\n";
				s += "您确定出售吗？\n";
				s += "[确定:home_shopItem_marked_price_confirm 0 "+name+" "+count+" "+timeDelay+" "+price+" "+ind+"]\n";
				s += "[我再想想:home_myzone]\n";
			}
		}

	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
