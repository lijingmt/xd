#include <command.h>
#include <gamelib/include/gamelib.h>

//装门

int main(string arg)
{
	object me = this_player();
	string s = "";
	string s_log = "";//日志
	string dr_name = arg;//门
	string hm_name = "";//锤子
	//sscanf(arg,"%s %s",dr_name,hm_name);
	//object dr_ob = (object)(ITEM_PATH+dr_name);
	//object hm_ob = (object)(ITEM_PATH+hm_name);
	object door = present(dr_name,me,0);
	object room = environment(me);
	if(!door){
		s += "- -!想装这样的门，先去买了再说吧~~杂货商人那里就有\n";
		s += "\n[返回:home_myzone]\n";
		//s += "\n[返回:door_destroy_entry "+dr_name+"]\n";
		s += "[返回游戏:look]\n";
		return 1;
	}
	else {
		s += "您装上了一扇坚固度为"+door->value+"的"+door->query_name_cn()+"\n";
		string st = room->query_door();
		if(st!=""&&(st/",")[0]=="1"){
			object dr_hv = clone(ITEM_PATH+(st/",")[1]);
			if(dr_hv->value>door->value){
				s += "您家的门的坚固度越来越弱了，这又给小偷增加了一些机会，建议您还是换回刚才的门吧\n";
			}
			else 
				s += "您的家比以前安全了许多~~\n";
			dr_hv->move(me);
		}
		//s += "您的家比以前安全了许多~~\n";
		HOMED->save_door("1,door/"+dr_name);
		door->remove();
	}
	s += "\n[返回:home_myzone]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
