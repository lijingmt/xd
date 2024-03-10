#include <command.h>  
#include <gamelib/include/gamelib.h>
#define	PAGE_LENGTH 9

int main(string arg)
{
	object me = this_player();
	int goods_type = 0;
	int pageNum = 0;
	string goods_name_cn = "";
	string goods_tmp = "";
	int orderType = 0;
	int flag=0;
	string tmp = "";
	if(arg&&sizeof(arg))
		//在这里多加了一个参数goods_name = "all"时表示无指定查询
		//orderType == 1 按名称来排序
		//             2 按物品等级排序
		//			   3 按物品稀有度排序
		sscanf(arg,"%d %d %d %d %s",goods_type,pageNum,orderType,flag,goods_tmp);
	if(arg&&flag){
		sscanf(goods_tmp,"gd=%s",tmp);
		goods_name_cn = tmp;
	}
	array(mapping(string:mixed)) sale_info = AUCTIOND->query_sale_infos(goods_name_cn,goods_type,orderType);

	if(flag)
		goods_name_cn = goods_tmp;
	string s = "[武器:vendue_goods_list 1 0 0 0 all]|[防具:vendue_goods_list 2 0 0 0 all]|[首饰:vendue_goods_list 3 0 0 0 all]|[饰物:vendue_goods_list 4 0 0 0 all]|[其他:vendue_goods_list 5 0 0 0 all]\n";
	s += "[string gd:...]";
	s += "[submit 搜索:vendue_goods_list "+goods_type+" 0 0 1"+" ...]\n";
	s += "--------\n";
	s += "[名称:vendue_goods_list "+goods_type+" "+pageNum+" 1 "+flag+" "+goods_name_cn+"]|";
	s += "[等级:vendue_goods_list "+goods_type+" "+pageNum+" 2 "+flag+" "+goods_name_cn+"]|";
	s += "当前价|";
	s += "一口价|\n";

	int item_length = sizeof(sale_info);
	int startPos = pageNum*PAGE_LENGTH;
	int endPos = (pageNum+1)*PAGE_LENGTH;
	if(endPos > item_length)
		endPos = item_length;
	

	for(int i = startPos; i < endPos; i++)
	{
		mapping(string:mixed) tempMap = sale_info[i];
		int id = (int)tempMap["sale_id"];// 获得拍卖号
		string name_cn = tempMap["goods_name_cn"]; //获得拍卖物品名		
		int level = tempMap["goods_level"]; //获得物品等级
		string cur_value = MUD_MONEYD->query_other_money_cn((int)tempMap["cur_value"]); //获得当前竞价
		int end_value_int = (int)tempMap["end_value"];
		string end_value = "";
		if(end_value_int == 0)
			end_value = "无";
		else 
			end_value = MUD_MONEYD->query_other_money_cn(end_value_int);
		s += "["+name_cn+":vendue_goods_info "+id+" 0]x"+tempMap["goods_count"]+"| "+level+" |"+cur_value+"|"+end_value+"\n";
	}
	//if(flag)
	//	goods_name_cn = goods_tmp;
	if(endPos < item_length)
		s += "[下一页:vendue_goods_list "+goods_type+" "+(pageNum+1)+" "+orderType+" "+flag+" "+goods_name_cn+"]\n";
	if(pageNum>0)
		s += "[上一页:vendue_goods_list "+goods_type+" "+(pageNum-1)+" "+orderType+" "+flag+" "+goods_name_cn+"]\n";
	
//	s += "[string goods:...]";
//	s += "[submit 搜索:vendue_goods_list 0 0 0 1 ...]\n";

	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "[返回:vendue_goods_list]\n";
	//s += "[返回游戏:look]\n";
	//write(s);
	return 1;
}
