#include <command.h>
#include <gamelib/include/gamelib.h>

#define ITEM_PATH ROOT "/gamelib/clone/item/"
//∏√÷∏¡Ó”√”⁄π∫¬ÚŒÔ∆∑µ˜”√

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
		s = "ƒ˙œÎπ∫¬Ú–© ≤√¥£∫\n";
		s += "-------\n";
		if(type == "jianxian")
			s += "Ω£œ…|[” ø:buy_items "+item_type+" yushi]|[÷Ôœ…:buy_items "+item_type+" zhuxian]\n";
		else if(type == "yushi")
			s += "[Ω£œ…:buy_items "+item_type+" jianxian]|” ø|[÷Ôœ…:buy_items "+item_type+" zhuxian]\n";
		else if(type == "zhuxian")
			s += "[Ω£œ…:buy_items "+item_type+" jianxian]|[” ø:buy_items "+item_type+" yushi]|÷Ôœ…\n";
		else if(type == "kuangyao")
			s += "øÒ—˝|[Œ◊—˝:buy_items "+item_type+" wuyao]|[”∞πÌ:buy_items "+item_type+" yinggui]\n";
		else if(type == "wuyao")
			s += "[øÒ—˝:buy_items "+item_type+" kuangyao]|Œ◊—˝|[”∞πÌ:buy_items "+item_type+" yinggui]\n";
		else if(type == "yinggui")
			s += "[øÒ—˝:buy_items "+item_type+" kuangyao]|[Œ◊—˝:buy_items "+item_type+" kuangyao]|”∞πÌ\n";
		else if(type=="goudou")
			s += "π∑∂π|[π∑¡∏:buy_items "+item_type+" gouliang]|[π«Õ∑:buy_items "+item_type+" gutou]\n";
		else if(type=="gouliang")
			s += "[π∑∂π:buy_items "+item_type+" goudou]|π∑¡∏|[π«Õ∑:buy_items "+item_type+" gutou]\n";
		else if(type=="gutou")
			s += "[π∑∂π:buy_items "+item_type+" goudou]|[π∑¡∏:buy_items "+item_type+" gouliang] |π«Õ∑\n";
		s += BUYD->get_buy_item_list(item_type,type);
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else {
		sscanf(arg,"%s %s %s %d %d %d",item_type,type,item_name,yushi,money,flag);
		if(flag==0){
			s += BUYD->item_view(item_name,yushi,money);
			s += "[π∫¬Ú:buy_items "+item_type+" "+type+" "+item_name+" "+yushi+" "+money+" 1]\n";
		}
		else if(flag==1){
			s += BUYD->buy_items(item_name,item_type);
		}
		s += "[∑µªÿ:buy_items "+item_type+" "+type+"]\n";
		s += "[∑µªÿ”Œœ∑:look]\n";
		write(s);
		return 1;  
	}
}
