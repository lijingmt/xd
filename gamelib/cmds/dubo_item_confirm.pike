#include <command.h>
#include <gamelib/include/gamelib.h>
//确定赌装
//arg = item_name index range level type
int main(string|zero arg)
{
	object me = this_player();
	string item_name = "";
	int index;
	int range;
	int requested_level;
	int requested_type;
	string s = "";
	if(!arg || sscanf(arg,"%s %d %d %d %d",item_name,index,range,
	   requested_level,requested_type)!=5){
		write("交易参数无效。\n[返回:dubo_items_list]\n[返回游戏:look]\n");
		return 1;
	}
	mapping(string:mixed) offer=DUBOD->query_dubo_offer(index,range);
	if(!sizeof(offer) || offer["name"]!=item_name){
		write("交易失败！没有此物品或者物品已经售完\n"+
			"[返回:dubo_items_list "+range+"]\n[返回游戏:look]\n");
		return 1;
	}
	int item_level=(int)offer["price"];
	int type=(int)offer["type"];
	//string s_log = me->query_name_cn()+"("+me->query_name()+"):";
	string s_log = "";
	int need_xianyuan = 0;
	int need_suiyu = 0;
	if(item_level>0 && item_level<100){
		need_xianyuan = item_level/10;
		need_suiyu = item_level%10;
	}
	if(!YUSHID->have_enough_yushi(me,item_level))
		s += "交易失败！你身上没有足够的玉石\n";
	else if(me->if_over_easy_load())
		s += "交易失败！你的随身物品已满\n";
	else{
		//交易成功
		int luck = 3000+me->query_lunck();
		object get_item;
		int get_item_num = 1;
		if(type == 1){
			mixed err=catch{
				get_item = clone(ITEM_PATH+item_name);
			};
			if(!err && get_item){
				int ran = random(101);
				if(ran <= 10)
					get_item->amount = 3;
				else if(ran <= 30)
					get_item->amount = 2;
				else
					get_item->amount = 1;
				get_item_num = get_item->amount;
			}
		}
		else
			get_item = ITEMSD->dubo_item(item_level,item_name,luck);
		if(get_item){
			//扣除玩家身上玉石
			string cost = "";
			string get_item_cn = get_item->query_name_cn();
			if(need_xianyuan){
				cost += need_xianyuan+"|xianyuanyu,";
			}
			if(need_suiyu){
				cost += need_suiyu+"|suiyu,";
			}
			if(!YUSHID->pay_yushi(me,item_level)){
				s += "交易失败！玉石扣除失败，请稍后再试\n";
				destruct(get_item);
			}
			else{
				DUBOD->set_dubo_num(item_name,index,range);
				s += "交易成功！你获得了"+get_item->query_short()+"\n";
				int cost_reb = item_level;
				 string c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][dubo]["+get_item->query_name()+"]["+get_item_cn+"][1]["+cost_reb+"][0]\n";
				if(get_item->is_combine_item()==1)
					get_item->move_player(me->query_name());
				else
					get_item->move(me);
				mixed log_err=catch{
					Stdio.append_file(ROOT+"/log/stat/consume/"+
						GAME_NAME_S+"_consume_"+
						MUD_TIMESD->get_year_month_day()+".log",c_log);
				};
				if(log_err)
					werror("[DUBO_AUDIT] append failed: %s\n",
						describe_error(log_err));
			}
		}
		else
			s += "交易失败！目标物品暂时无法生成\n";
	}
	s += "[返回:dubo_items_list "+range+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
