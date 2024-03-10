#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = type item_num 
//      type = "weapon" "armor" "jewelry"
//      item_num    标识第几个物品栏
//此指令在玩家熔解物品时最先调用，列出玩家熔炼ui
int main(string arg)
{
	string s = "";
	object me=this_player();
	string type = "";
	int num = 0;
	string item_name = "";
	sscanf(arg,"%s %d",type,num);
	if(me->vice_skills["duanzao"] == 0)
		s += "你现在并不会锻造技能\n";
	else{
		if(num == 1)
			s += "选择参与熔炼的物品一\n";
		else if(num == 2)
			s += "选择参与熔炼的物品二\n";
		if(type == "weapon"){
			s += "武器|[防具:viceskill_ronglian_item armor "+num+"]|[首饰:viceskill_ronglian_item jewelry "+num+"]\n";	
		}
		else if(type == "armor"){
			s += "[武器:viceskill_ronglian_item weapon "+num+"]|防具|[首饰:viceskill_ronglian_item jewelry "+num+"]\n";	
		}
		else if(type == "jewelry"){
			s += "[武器:viceskill_ronglian_item weapon "+num+"]|[防具:viceskill_ronglian_item armor "+num+"]|首饰\n";	
		}
		s += RONGLIAND->query_can_ronglian(me,type,num);
		s += "\n[返回:viceskill_ronglian_list 1]\n";
	}
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
