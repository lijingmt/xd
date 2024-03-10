#include <command.h>
#include <gamelib/include/gamelib.h>
//查看指定的赌装装备
//arg = item_name index range
int main(string arg)
{
	object me = this_player();
	object item;
	string item_name = "";
	int index;
	int range;
	int type = 0;//赌博物品的类新，0-装备，1-道具
	sscanf(arg,"%s %d %d",item_name,index,range);
	string s = "我们这儿的物品是很有限的，欲购从速：\n";
	mixed err = catch{
		item = (object)(ITEM_PATH+item_name);
	};
	if(!err && item){
		s += item->query_name_cn()+"\n";
		s += item->query_picture_url()+"\n";
		s += item->query_desc()+"\n";
		if(!item->is_combine_item())
			s += item->query_content()+"\n";
		s += "需要：";
		int item_level = 0;
		if(item->is_combine_item()==1 && (item->query_for_material()=="baoshi"||item->query_for_material()=="moxian")){
			item_level = item->query_item_level();
			type = 1;
		}
		else
			item_level = item->query_item_canLevel();
		int half = DUBOD->query_half_price();                                           
		if(item_level <= half*10 && item_level >= (half*10-9))                          
			item_level = item_level/2;                                              
		if(item_level <= 0)                                                             
			item_level = 1;
		int need_xianyuan = 0;
		int need_suiyu = 0;
		if(item_level>0 && item_level<100){
			need_xianyuan = item_level/10;
			need_suiyu = item_level%10;
		}
		if(need_xianyuan)
			s += need_xianyuan+"【玉】仙缘玉 ";
		if(need_suiyu)
			s += need_suiyu+"【玉】碎玉\n";
		else
			s += "\n";
		s += "[赌一把:dubo_item_confirm "+item_name+" "+index+" "+range+" "+item_level+" "+type+"]\n";
	}
	else
		s += "此物品似乎出了些问题\n";
	s += "[返回:dubo_items_list "+range+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
