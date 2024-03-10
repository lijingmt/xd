#include <command.h>
#include <gamelib/include/gamelib.h>
#define	PAGE_LENGTH 10

int main(string arg)
{
	object me = this_player();
	int pageNum = 0;                                                                                                     
	if(arg&&sizeof(arg))
		sscanf(arg,"%d",pageNum);
	string s = "[拍卖新物品:inventory_vendue]\n";
	if(me->sid == "5dwap") 
		s = "你现在是游客试玩，无法拍卖你的物品\n";
	array(mapping(string:mixed)) result = AUCTIOND->query_my_sale_infos(me->name);
	s += "--------\n";
	s += "你正在拍卖的物品\n";
	s += "名称|等级|当前价|一口价|\n";

	int item_length = sizeof(result);
	if(!item_length){
		s += "无\n";
	}
	int startPos = pageNum*PAGE_LENGTH;
	int endPos = (pageNum+1)*PAGE_LENGTH;
	if(endPos > item_length)
		endPos = item_length;

	for(int i = startPos; i < endPos; i++)
	{
		mapping(string:mixed) tempMap = result[i];
		int id = (int)tempMap["sale_id"];// 获得拍卖号
		string name_cn = tempMap["goods_name_cn"]; //获得拍卖物品名		
		int level = (int)tempMap["goods_level"]; //获得物品等级
		string cur_value = MUD_MONEYD->query_other_money_cn((int)tempMap["cur_value"]); //获得当前竞价
		int end_value_int = (int)tempMap["end_value"];
		string end_value = "";
		if(end_value_int == 0)
			end_value = "无";
		else 
			end_value = MUD_MONEYD->query_other_money_cn(end_value_int);
		s += "["+name_cn+":vendue_goods_info "+id+" 1]x"+tempMap["goods_count"]+"|"+level+"|"+cur_value+"|"+end_value+"|\n";
	}

	if(endPos < item_length)
		s += "[下一页:vendue_mygoods_list " + (pageNum+1) + "]\n";
	if(pageNum>0)                                                                                                        
		s += "[上一页:vendue_mygoods_list " + (pageNum-1) + "]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
