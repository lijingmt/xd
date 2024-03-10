#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = num flag name count 
//此指令在加入熔炼物品
int main(string arg)
{
	string s = "";
	object me=this_player();
	int num = 0;
	int flag = 0;
	string item_name = "";
	int count = 0;
	sscanf(arg,"%d %d %s %d",num,flag,item_name,count);
	if(me->vice_skills["duanzao"] == 0)
		s += "你现在并不会锻造技能\n";
	else{
		object ob = present(item_name,me,count);
		if(!ob){
			s += "你没有此物品\n";
		}
		else{
			if(flag == 0){
				s += ob->query_name_cn()+"\n";
				s += ob->query_desc()+"\n";
				s += ob->query_content()+"\n";
				s += "\n[加入熔炼:viceskill_ronglian_add "+num+" 1 "+item_name+" "+count+"]\n";
				s += "[返回:viceskill_ronglian_list 1]\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			else if(flag == 1){
				me->ronglian_list[num] = ({item_name,count});
				me->command("viceskill_ronglian_list 1");
				return 1;
			}
		}
	}
	s += "\n[返回:viceskill_ronglian_list 1]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//write(s);
	return 1;
}
