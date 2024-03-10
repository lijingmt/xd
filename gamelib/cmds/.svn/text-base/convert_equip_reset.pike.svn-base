#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令完成利用宝石使转化次数为零的过程
//arg 想要清零的物品名称·

int main(string arg)
{
	string s = "";
	string item_name = arg;//玩家想要转化的物品文件名
	string log_consume = "convert";
	object me=this_player();
	object item;//玩家想要转化的物品object
	int can_reset = 0;
	int flag = 0;
	int have_zijinyushi = 0;
	int rareLevel = 0;//物品的稀有等级
	array(object) all_obj = all_inventory(me);
	foreach(all_obj,object ob){
		if(ob && ob->query_item_rareLevel()>0 && !ob["equiped"]){
			if(ob->query_name() == item_name){
				can_reset = 1;
				item = ob;
				break;
			}
		}
	}
	foreach(all_obj,object ob1){
		if(ob1 && ob1->query_name()=="zijinyushi")
		{
			have_zijinyushi = 1;
			break;
		}
	}
	//玩家身上该物品和紫晶玉石，且物品不出于佩戴状态，则把转化次数清零，同时扣除紫晶玉石
	if(can_reset && have_zijinyushi && item){
		if(item->query_convert_count()==0){
			s += "您的转化次数已经是零，不要浪费玉石哦\n";			
			s += "[返回:convert_equip_list]\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
		else{
			item->set_convert_count(0);
			me->remove_combine_item("zijinyushi",1);
			me->command("convert_equip_detail "+item_name+" 4");
			return 1;
		}
	}
	else if(!have_zijinyushi){
		s += "清零失败！您身上没有紫金玉石\n";
	}
	else s += "您要清零的物品不存在，请返回";
	s += "[返回:convert_equip_list]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
