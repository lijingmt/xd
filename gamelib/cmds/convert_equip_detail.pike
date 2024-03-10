#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令列出具体的玩家指定的需要转换的某种装备的信息
//arg = item_name 
//      cost    当flag==1或==2时需要的玉石花费
//      flag    0 --第一次进入此页面  1--转化成功  2--增加成功 3--增加失败  4--清零成功                 
int main(string arg)
{
	string s = "";
	string item_name = "";//玩家想要转化的物品文件名
	object me=this_player();
	object item;//玩家想要转化的物品object
	int can_convert = 0;
	int flag = 0;
	int rareLevel = 0;//物品的稀有等级
	int canLevel = 0;//物品的穿戴等级
	int convert_cost = 0;//属性转化需要的玉石数
	int add_cost = 0;//增加属性需要的玉石数
	sscanf(arg,"%s %d",item_name,flag);
	array(object) all_obj = all_inventory(me);
	foreach(all_obj,object ob){
		//if(ob && ob->query_item_rareLevel()>0 && !ob["equiped"]){
		if(ob && ITEMSD->can_equip(ob) &&((ob->query_item_rareLevel()>0)||(ob->query_item_canLevel()>=1&&(sizeof(ob->query_name_cn()/"】"))==1))){
			if(ob->query_name() == item_name){
				can_convert = 1;
				item = ob;
				break;
			}
		}
	}
	if(can_convert && item){
		if(flag == 1){
			s += "转化成功！(^0^)\n";
			//if(me->query_vip_flag())
			//	s += "由于你是会员，本次操作完全免费！\n";
		}
		else if(flag == 2)
			s += "增加成功！(^0^)\n";
		else if(flag == 3)
			s += "增加失败！(T_T)\n";
		else if(flag == 4)
			s += "清零成功！(^0^)\n";
		rareLevel = item->query_item_rareLevel();
		canLevel = item->query_item_canLevel();
		//确定转化需要的玉石数
		switch(canLevel){
			case 1..10:
				convert_cost = 2;
				break;
			case 11..20:
				convert_cost = 4;
				break;
			case 21..30:
				convert_cost = 6;
				break;
			case 31..40:
				convert_cost = 8;
				break;
			case 41..49:
				convert_cost = 10;
				break;
			default:
				convert_cost = 10;
		}
		//得到增加属性需要消耗的玉石数
		add_cost = convert_cost;
		/*
		   switch(canLevel){
		   case 1..9:
		   add_cost = canLevel;
		   break;
		   case 10..18:
		   add_cost = 10;
		   break;
		   case 19..28:
		   add_cost = 20;
		   break;
		   case 29..38:
		   add_cost = 30;
		   break;
		   case 39..48:
		   add_cost = 40;
		   break;
		   case 49:
		   add_cost = 50;
		   break;
		   default:
		   add_cost = 50;
		   }
		 */
		//获得需要的金钱数
		string s_money = MUD_MONEYD->query_other_money_cn(canLevel*100);
		s += item->query_name_cn()+"\n";
		s += item->query_picture_url()+"\n"+item->query_desc()+"\n";
		s += item->query_content()+"\n";
		int have_binglanyushi = 0;
		int have_zijinyushi = 0;
		int have_huposhi = 0;
		int have_cuijinshi = 0;
		array(object) all_obj = all_inventory(me);
		foreach(all_obj,object ob){
			if(ob && ob->query_name()=="binglanyushi"){
				have_binglanyushi += ob->amount;
			}
			if(ob && ob->query_name()=="zijinyushi"){
				have_zijinyushi += ob->amount;
			}
			if(ob && ob->query_name()=="huposhi"){
				have_huposhi += ob->amount;
			}
			if(ob && ob->query_name()=="cuijinshi"){
				have_cuijinshi += ob->amount;
			}
		}
		if(item->query_item_rareLevel()!=0){
			s += "转化需要："+YUSHID->get_yushi_for_desc(convert_cost)+","+s_money+"\n";
			s += "[转化属性:convert_equip_confirm "+item->query_name()+" "+item->query_item_type()+" "+convert_cost+" 1 0]\n";
			s += "[会员免费转化:convert_equip_confirm "+item->query_name()+" "+item->query_item_type()+" 0 1 1]\n";
			s += "[转化次数清零:convert_equip_reset "+item->query_name()+"](x"+have_zijinyushi+")\n";}
			s += "增加需要："+YUSHID->get_yushi_for_desc(add_cost)+","+s_money+"\n";
			s += "[增加属性:convert_equip_confirm "+item->query_name()+" "+item->query_item_type()+" "+add_cost+" 2 0]\n";
			s += "[会员优惠增加属性:convert_equip_vip_off "+item->query_name()+" "+item->query_item_type()+" "+add_cost+" 2]\n";
			s += "[冰蓝玉石辅助增加:convert_equip_confirm "+item->query_name()+" "+item->query_item_type()+" "+add_cost+" 3](x"+have_binglanyushi+")\n";
			if(item->query_item_rareLevel()==0){
				s += "[琥珀石辅助增加:convert_equip_confirm "+item->query_name()+" "+item->query_item_type()+" "+add_cost+" 4](x"+have_huposhi+")\n";
			}
			if(item->query_item_rareLevel()==1||item->query_item_rareLevel()==2){
				s += "[翠晶石辅助增加:convert_equip_confirm "+item->query_name()+" "+item->query_item_type()+" "+add_cost+" 5](x"+have_cuijinshi+")\n";
			}
	}
	else 
		s += "你要炼化的装备并不存在，请返回\n";
	s += "[返回:convert_equip_list]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
	}
