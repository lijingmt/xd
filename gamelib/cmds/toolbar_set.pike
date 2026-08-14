#include <command.h>
#include <gamelib/include/gamelib.h>
#define FOOD_PATH ROOT "/gamelib/clone/item/food/"
#define WATER_PATH ROOT "/gamelib/clone/item/water/"
//arg = num name
int main(string|zero arg)
{
	int num;
	string name = "";
	int flag; //1-技能 2-食物 3-水 4-自杀药
	string s = "";
	string name_cn = "";
	object me = this_player();
	if(!arg || sscanf(arg,"%d %s %d",num,name,flag)!=3 ||
	   num<0 || num>=me->query_toolbar_slot_limit() ||
	   flag<1 || flag>3){
		s = "快捷栏参数无效，设置没有生效。\n";
	}
	else
		name_cn = (string)me->query_toolbar_entry_name(name,flag);
	if(name_cn!="" && me->set_toolbar(name,num,flag)){
		s = "你将快捷键"+(num+1)+"设置成为";
		if(flag==1)
			s += "施放"+name_cn+"\n";
		else if(flag==2)
			s += "食用"+name_cn+"\n";
		else if(flag==3)
			s += "饮用"+name_cn+"\n";
	}
	else if(s=="")
		s = "该技能或药品已经失效，设置没有生效。\n";
	s += "[返回:my_toolbar]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
