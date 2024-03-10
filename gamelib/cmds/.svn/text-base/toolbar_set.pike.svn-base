#include <command.h>
#include <gamelib/include/gamelib.h>
#define FOOD_PATH ROOT "/gamelib/clone/item/food/"
#define WATER_PATH ROOT "/gamelib/clone/item/water/"
//arg = num name
int main(string arg)
{
	int num;
	string name = "";
	int flag; //1-技能 2-食物 3-水 4-自杀药
	sscanf(arg,"%d %s %d",num,name,flag);
	string s = "";
	string name_cn="";
	if(this_player()->set_toolbar(name,num,flag)){
		s = "你将快捷键"+(num+1)+"设置成为";
		if(flag==1){
			name_cn = MUD_SKILLSD[name]->query_name_cn();
			s += "施放"+name_cn+"\n";
		}
		else if(flag==2){
			object food = clone(FOOD_PATH+name);
			if(food){
				name_cn = food->query_name_cn();
				s += "食用"+name_cn+"\n";
			}
		}
		else if(flag == 3){
			object water = clone(WATER_PATH+name);
			if(water){
				name_cn = water->query_name_cn();
				s += "饮用"+name_cn+"\n";
			}
		}
	}
	else 
		s += "设置失败\n";
	s += "[返回:my_toolbar]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}

