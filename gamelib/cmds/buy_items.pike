#include <command.h>
#include <gamelib/include/gamelib.h>

#ifndef ITEM_PATH
#define ITEM_PATH ROOT "/gamelib/clone/item/"
#endif
//该指令用于购买物品调用

int main(string|zero arg)
{
	object me = this_player();
	object item_ob;
	string type;
	string item_type;
	string item_name = "";
	string s = "";
	int flag = 0;
	int buy_count = 1;
	string buy_count_arg = "";
	int yushi,money;
	//int need_yushi = 0;
	//int need_money = 0;
	if(!me || !arg || String.trim_all_whites(arg)==""){
		write("请选择要购买的物品。\n[返回游戏:look]\n");
		return 1;
	}
	int parsed=sscanf(arg,"%s %s %s %d %d %d %s",item_type,type,
		item_name,yushi,money,flag,buy_count_arg);
	if(parsed==7)
		buy_count=SHOP_BATCHD->parse_count(buy_count_arg);
	if(parsed!=7)
		parsed=sscanf(arg,"%s %s %s %d %d %d",item_type,type,
			item_name,yushi,money,flag);
	if(parsed!=6 && parsed!=7){
		sscanf(arg,"%s %s",item_type,type);
		s = "您想购买些什么：\n";
		s += "-------\n";
		// 技能书商店始终由服务端锁定到人物本职业，避免伪造跨职业购买。
		if(item_type=="book"){
			type = me->query_profeId();
			s += BUYD->get_buy_item_list(item_type,type);
			NEWBIED->record_book_shop(me,type);
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		if(type == "jianxian")
			s += "剑仙|[羽士:buy_items "+item_type+" yushi]|[诛仙:buy_items "+item_type+" zhuxian]|[方士:buy_items "+item_type+" fangshi]|[镇越:buy_items "+item_type+" zhenyue]|[天象:buy_items "+item_type+" tianxiang]|[灵医:buy_items "+item_type+" lingyi]|[无相:buy_items "+item_type+" wuxiang]|[无极:buy_items "+item_type+" wuji]|[无心:buy_items "+item_type+" wuxin]\n";
		else if(type == "yushi")
			s += "[剑仙:buy_items "+item_type+" jianxian]|羽士|[诛仙:buy_items "+item_type+" zhuxian]|[方士:buy_items "+item_type+" fangshi]|[镇越:buy_items "+item_type+" zhenyue]|[天象:buy_items "+item_type+" tianxiang]|[灵医:buy_items "+item_type+" lingyi]|[无相:buy_items "+item_type+" wuxiang]|[无极:buy_items "+item_type+" wuji]|[无心:buy_items "+item_type+" wuxin]\n";
		else if(type == "zhuxian")
			s += "[剑仙:buy_items "+item_type+" jianxian]|[羽士:buy_items "+item_type+" yushi]|诛仙|[方士:buy_items "+item_type+" fangshi]|[镇越:buy_items "+item_type+" zhenyue]|[天象:buy_items "+item_type+" tianxiang]|[灵医:buy_items "+item_type+" lingyi]|[无相:buy_items "+item_type+" wuxiang]|[无极:buy_items "+item_type+" wuji]|[无心:buy_items "+item_type+" wuxin]\n";
		else if(type == "fangshi")
			s += "[剑仙:buy_items "+item_type+" jianxian]|[羽士:buy_items "+item_type+" yushi]|[诛仙:buy_items "+item_type+" zhuxian]|方士|[镇越:buy_items "+item_type+" zhenyue]|[天象:buy_items "+item_type+" tianxiang]|[灵医:buy_items "+item_type+" lingyi]|[无相:buy_items "+item_type+" wuxiang]|[无极:buy_items "+item_type+" wuji]|[无心:buy_items "+item_type+" wuxin]\n";
		else if(type == "zhenyue")
			s += "[剑仙:buy_items "+item_type+" jianxian]|[羽士:buy_items "+item_type+" yushi]|[诛仙:buy_items "+item_type+" zhuxian]|[方士:buy_items "+item_type+" fangshi]|镇越|[天象:buy_items "+item_type+" tianxiang]|[灵医:buy_items "+item_type+" lingyi]|[无相:buy_items "+item_type+" wuxiang]|[无极:buy_items "+item_type+" wuji]|[无心:buy_items "+item_type+" wuxin]\n";
		else if(type == "tianxiang")
			s += "[剑仙:buy_items "+item_type+" jianxian]|[羽士:buy_items "+item_type+" yushi]|[诛仙:buy_items "+item_type+" zhuxian]|[方士:buy_items "+item_type+" fangshi]|[镇越:buy_items "+item_type+" zhenyue]|天象|[灵医:buy_items "+item_type+" lingyi]|[无相:buy_items "+item_type+" wuxiang]|[无极:buy_items "+item_type+" wuji]|[无心:buy_items "+item_type+" wuxin]\n";
		else if(type == "lingyi")
			s += "[剑仙:buy_items "+item_type+" jianxian]|[羽士:buy_items "+item_type+" yushi]|[诛仙:buy_items "+item_type+" zhuxian]|[方士:buy_items "+item_type+" fangshi]|[镇越:buy_items "+item_type+" zhenyue]|[天象:buy_items "+item_type+" tianxiang]|灵医|[无相:buy_items "+item_type+" wuxiang]|[无极:buy_items "+item_type+" wuji]|[无心:buy_items "+item_type+" wuxin]\n";
		else if(type == "wuxiang")
			s += "[剑仙:buy_items "+item_type+" jianxian]|[羽士:buy_items "+item_type+" yushi]|[诛仙:buy_items "+item_type+" zhuxian]|[方士:buy_items "+item_type+" fangshi]|[镇越:buy_items "+item_type+" zhenyue]|[天象:buy_items "+item_type+" tianxiang]|[灵医:buy_items "+item_type+" lingyi]|无相|[太极:buy_items "+item_type+" taiji]\n";
		else if(type == "taiji")
			s += "[剑仙:buy_items "+item_type+" jianxian]|[羽士:buy_items "+item_type+" yushi]|[诛仙:buy_items "+item_type+" zhuxian]|[方士:buy_items "+item_type+" fangshi]|[镇越:buy_items "+item_type+" zhenyue]|[天象:buy_items "+item_type+" tianxiang]|[灵医:buy_items "+item_type+" lingyi]|[无相:buy_items "+item_type+" wuxiang]|太极\n";
		else if(type == "kuangyao")
			s += "狂妖|[巫妖:buy_items "+item_type+" wuyao]|[影鬼:buy_items "+item_type+" yinggui]|[方士:buy_items "+item_type+" fangshi]|[镇越:buy_items "+item_type+" zhenyue]|[天象:buy_items "+item_type+" tianxiang]|[灵医:buy_items "+item_type+" lingyi]|[无相:buy_items "+item_type+" wuxiang]|[无极:buy_items "+item_type+" wuji]|[无心:buy_items "+item_type+" wuxin]\n";
		else if(type == "wuyao")
			s += "[狂妖:buy_items "+item_type+" kuangyao]|巫妖|[影鬼:buy_items "+item_type+" yinggui]|[方士:buy_items "+item_type+" fangshi]|[镇越:buy_items "+item_type+" zhenyue]|[天象:buy_items "+item_type+" tianxiang]|[灵医:buy_items "+item_type+" lingyi]|[无相:buy_items "+item_type+" wuxiang]|[无极:buy_items "+item_type+" wuji]|[无心:buy_items "+item_type+" wuxin]\n";
		else if(type == "yinggui")
			s += "[狂妖:buy_items "+item_type+" kuangyao]|[巫妖:buy_items "+item_type+" wuyao]|影鬼|[方士:buy_items "+item_type+" fangshi]|[镇越:buy_items "+item_type+" zhenyue]|[天象:buy_items "+item_type+" tianxiang]|[灵医:buy_items "+item_type+" lingyi]|[无相:buy_items "+item_type+" wuxiang]|[无极:buy_items "+item_type+" wuji]|[无心:buy_items "+item_type+" wuxin]\n";
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
		if(item_type=="book" && type!=me->query_profeId()){
			write("只能购买自己职业的技能书。\n[返回:buy_items book "+
				me->query_profeId()+"]\n[返回游戏:look]\n");
			return 1;
		}
		if(flag==0){
			s += BUYD->item_view(item_name,yushi,money);
			mapping offer=BUYD->query_buy_offer(me,item_name,item_type,type);
			if((int)offer["ok"] && (int)offer["combine"]){
				foreach(({1,5,10,20,50,100}),int quick)
					s += "[买"+quick+"个:buy_items "+item_type+" "+
						type+" "+item_name+" "+yushi+" "+money+" 1 "+
						quick+"] ";
				s += "\n自定义数量(1-100)：[int no:...]\n"+
					"[submit 确定购买:buy_items "+item_type+" "+type+" "+
					item_name+" "+yushi+" "+money+" 1 ...]\n";
			}
			else
				s += "[购买:buy_items "+item_type+" "+type+" "+
					item_name+" "+yushi+" "+money+" 1]\n";
		}
		else if(flag==1){
			s += BUYD->buy_items(item_name,item_type,type,buy_count);
		}
		s += "[返回:buy_items "+item_type+" "+type+"]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;  
	}
}
