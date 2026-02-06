#include <command.h>
#include <gamelib/include/gamelib.h>

#define ITEM_PATH ROOT "/gamelib/clone/item/"
//该指令用于购买物品调用

int main(string arg)
{
	object me = this_player();
	object item_ob;
	string type;
	string item_type;
	string item_name = "";
	string s = "";
	int flag = 0;
	int yushi,money;
	//int need_yushi = 0;
	//int need_money = 0;
	if(sscanf(arg,"%s %s %s %d %d %d",item_type,type,item_name,yushi,money,flag)!=6){
		sscanf(arg,"%s %s",item_type,type);
		s = "您想购买些什么：\n";
		s += "-------\n";
		if(type == "jianxian")
			s += "剑仙|[羽士:buy_items "+item_type+" yushi]|[诛仙:buy_items "+item_type+" zhuxian]\n";
		else if(type == "yushi")
			s += "[剑仙:buy_items "+item_type+" jianxian]|羽士|[诛仙:buy_items "+item_type+" zhuxian]\n";
		else if(type == "zhuxian")
			s += "[剑仙:buy_items "+item_type+" jianxian]|[羽士:buy_items "+item_type+" yushi]|诛仙\n";
		else if(type == "kuangyao")
			s += "狂妖|[巫妖:buy_items "+item_type+" wuyao]|[影鬼:buy_items "+item_type+" yinggui]\n";
		else if(type == "wuyao")
			s += "[狂妖:buy_items "+item_type+" kuangyao]|巫妖|[影鬼:buy_items "+item_type+" yinggui]\n";
		else if(type == "yinggui")
			s += "[狂妖:buy_items "+item_type+" kuangyao]|[巫妖:buy_items "+item_type+" kuangyao]|影鬼\n";
		else if(type=="goudou")
			s += "狗豆|[狗粮:buy_items "+item_type+" gouliang]|[骨头:buy_items "+item_type+" gutou]\n";
		else if(type=="gouliang")
			s += "[狗豆:buy_items "+item_type+" goudou]|狗粮|[骨头:buy_items "+item_type+" gutou]\n";
		else if(type=="gutou")
			s += "[狗豆:buy_items "+item_type+" goudou]|[狗粮:buy_items "+item_type+" gouliang] |骨头\n";
		s += BUYD->get_buy_item_list(item_type,type);
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else {
		sscanf(arg,"%s %s %s %d %d %d",item_type,type,item_name,yushi,money,flag);
		if(flag==0){
			s += BUYD->item_view(item_name,yushi,money);
			s += "[购买:buy_items "+item_type+" "+type+" "+item_name+" "+yushi+" "+money+" 1]\n";
		}
		else if(flag==1){
			s += BUYD->buy_items(item_name,item_type);
		}
		s += "[返回:buy_items "+item_type+" "+type+"]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;  
	}
}
