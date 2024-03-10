#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	int type = 0;
	int sale_id = 0;
	sscanf(arg,"%d %d",type,sale_id);
	string s = "";

	mapping(string:mixed) sale_info = AUCTIOND->query_sale_info(sale_id);
	if(!sizeof(sale_info))
		s += "真不凑巧，此物品刚刚已经拍卖出去，或者已经到期了，下次记得动作迅速点\n";
	else{
		string goods_filename = sale_info["goods_filename"];
		object obj_item = clone(goods_filename);

		if(obj_item){
			s += obj_item->query_name_cn()+"\n";
			s += obj_item->query_picture_url()+"\n";
			s += obj_item->query_desc()+"\n";
			if(obj_item->profe_read_limit)
				s+="职业："+obj_item->profe_read_limit+"\n";
			if(obj_item->is("equip"))
				s += obj_item->query_content()+"\n";
			s += "拍卖人："+sale_info["saler_name"]+"\n";
			string buyer_name = "暂无";
			int cur_value = (int)sale_info["cur_value"];
			string cur_value_s = MUD_MONEYD->query_other_money_cn(cur_value);
			if((int)sale_info["buy_flag"]) //有人竟标
				buyer_name = sale_info["winner_name"];
			s += "当前价："+cur_value_s+"\n";
			s += "竞标人："+buyer_name+"\n";
			int end_value = (int)sale_info["end_value"];
			string end_value_s = MUD_MONEYD->query_other_money_cn(end_value);
			if(!end_value)
				end_value_s = "无";
			s += "一口价："+end_value_s+"\n";
			int iopen_time = (int)sale_info["iopen_time"];
			string iopen_time_desc = AUCTIOND->get_time_desc(iopen_time);
			s += "剩余时间："+iopen_time_desc+"\n";

			if((int)sale_info["sale_status"])
				s +="该物品已经竞拍了出去\n";
			else if(me->query_name() == sale_info["saler_id"])
				s += "自己不能竞拍自己拍卖的物品，请确认后重试。\n";
			else if(type == 2)
			{
				s += "输入竞拍价格：\n";
				s += "[int gd:...]金[int sv:...]银\n";
				s += "[submit 确定:vendue_maunl_comp "+sale_id+" ...]\n"; //明天继续
			}
			else if(type == 3)
			{
				s += "你将以一口价"+end_value_s+"购买,确定？\n";
				s += "[确认购买:vendue_buy_now "+sale_id+"]";
			}
			else if(type == 1) //直接竞拍，系统自动给出竞拍价
			{
				int auto_value = (int)(cur_value*1.05);
				if(auto_value == cur_value)
					auto_value++;
				//11111这里需要添加玩家身上钱是否足够的判断
				if(auto_value > me->query_account())
					s += "你身上没有那么多钱~，请赚够钱后再来试试吧\n";
				else {
					//扣除玩家竞价的费用
					me->del_account(auto_value);
					if(end_value && auto_value>=end_value){
						if(!AUCTIOND->reset_sale_info(this_player(),sale_id,auto_value,1))
							s +="这笔拍卖已经结束了\n";
						else{
							s +="你的竞价超过了一口价，恭喜你，你赢得了对"+obj_item->query_name_cn()+"的竞拍\n";
							s +="请及时领取你的物品，7天后对于这些未认领的物品我们将一律回收，以解决现在非常时期的资源紧缺问题\n";
						}
					}
					else{
						if(!AUCTIOND->reset_sale_info(this_player(),sale_id,auto_value,0)) 
							s += "这笔拍卖已经结束了\n";
						else
							s += "你当前对"+obj_item->query_name_cn()+"的出价为"+MUD_MONEYD->query_other_money_cn(auto_value)+"\n";
					}
				}
			}
		}
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
