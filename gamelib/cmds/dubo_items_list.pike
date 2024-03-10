#include <command.h>
#include <gamelib/include/gamelib.h>
//付费赌博装备查看总列表
int main(string arg)
{
	object me = this_player();
	string s = "我们这儿的物品是很有限的，欲购从速：\n";
	if(!arg){
		int half = DUBOD->query_half_price();
		s += "[1-10级装备:dubo_items_list 1]";
		if(half == 1)
			s += "(折扣)";
		s += "\n[11-20级装备:dubo_items_list 2]";
		if(half == 2)
			s += "(折扣)";
		s += "\n[21-30级装备:dubo_items_list 3]";
		if(half == 3)
			s += "(折扣)";
		s += "\n[31-40级装备:dubo_items_list 4]";
		if(half == 4)
			s += "(折扣)";
		s += "\n[41-50级装备:dubo_items_list 5]";
		if(half == 5)
			s += "(折扣)";
		s += "\n[50级以上装备:dubo_items_list 6]";
		if(half == 6)
			s += "(折扣)";
		s += "\n[返回游戏:look]\n";
	}
	else{
		int range = (int)arg;
		s += DUBOD->query_dubo_items(range);
		s += "[返回:dubo_items_list]\n";
		s += "[返回游戏:look]\n";
	}
	write(s);
	return 1;
}
