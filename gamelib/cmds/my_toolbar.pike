#include <command.h>
#include <gamelib/include/gamelib.h>
#define FOOD_PATH ROOT "/gamelib/clone/item/food/"
#define WATER_PATH ROOT "/gamelib/clone/item/water/"
int main(string arg)
{
	string s = "点击快捷键,可进入配置页面，可配置的范围包括技能和可食用药品\n";
	string name_cn = "";
	object me = this_player();
	array(mapping(string:int)) tmps = me->query_toolbar_all();
	if(tmps&&sizeof(tmps)){
		for(int i=0;i<sizeof(tmps);i++){
			int j = i+1;
			mapping(string:int) tmp = tmps[i];
			string tmp_name;// = indices(tmp)[0];
			foreach(indices(tmp), string keys){
				tmp_name = keys;
				break;
			}
			if(tmp_name == "none" || tmp_name == "" )
				name_cn = "无";
			else{
				if(tmp[tmp_name] == 1){
					name_cn = MUD_SKILLSD[tmp_name]->query_name_cn(); 
				}
				else if(tmp[tmp_name] == 2){
					object food = clone(FOOD_PATH+tmp_name);
					if(food)
						name_cn = food->query_name_cn();
				}
				else if(tmp[tmp_name] == 3){
					object water = clone(WATER_PATH+tmp_name);
					if(water)
						name_cn = water->query_name_cn();
				}
				//s += "[快捷键"+j+":toolbar_view "+i+" skills] (当前配置:"+name_cn+")-[取消配置:toolbar_cancel "+i+"]\n";
			}
			s += "[快捷键"+j+":toolbar_view "+i+" skills] (当前配置:"+name_cn+")-[取消配置:toolbar_cancel "+i+"]\n";
		}
	}
	else
		s += "你的配置系统有问题，请联系管理员\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
