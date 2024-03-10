#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	int sale_id = 0;
	int flag = 0;
	sscanf(arg,"%d %d",sale_id,flag);
	string s = "";

	mapping(string:mixed) sale_info = AUCTIOND->query_sale_info(sale_id);

	if(!sizeof(sale_info))
		s += "真不凑巧，此物品刚刚已经拍卖出去，或者已经到期了，下次记得动作迅速点\n";
	else{
		string goods_filename = sale_info["goods_filename"];
		int convert_count = (int)sale_info["convert_count"];
		object obj_item = clone(goods_filename);
		if(obj_item){
			s += obj_item->query_name_cn()+"\n";
			s += obj_item->query_picture_url()+"\n";
			s += obj_item->query_desc()+"\n";
			if(obj_item->profe_read_limit)
				s+="职业："+obj_item->profe_read_limit+"\n";
			if(obj_item->is("equip")){
				obj_item->set_convert_count(convert_count);
				s += obj_item->query_content()+"\n";
			}
			s += "拍卖人："+sale_info["saler_name"]+"\n";
			string buyer_name = "暂无";
			string cur_value_s = MUD_MONEYD->query_other_money_cn((int)sale_info["cur_value"]);
			if(sale_info["buy_flag"]) //有人竟标
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
			if(flag == 0){
				//察看别人拍卖的东西
				if(me->sid != "5dwap"){
					s += "[直接竞拍:vendue_vie_buy 1 "+sale_id+"]\n" ;
					s += "[输入竞拍价:vendue_vie_buy 2 "+sale_id+"]\n";
					if(end_value)
						s += "[一口价购买:vendue_vie_buy 3 "+sale_id+"]";
				}
				else
					s += "\n你现在是游客试玩，无法竞拍物品\n";
			}
			else if(flag == 1)
				s += "[取消拍卖:vendue_cancel "+sale_id+"]\n";
		}
		else
			s += "你要竞买的物品并不存在\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
