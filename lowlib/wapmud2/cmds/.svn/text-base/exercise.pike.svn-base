#include <command.h>
#include <wapmud2/include/wapmud2.h>
#define TEMPLATE_PATH ROOT "/gamelib/d/home/template/"
//仿照sleep.pike写的一个家园系统中"获得buff"的方法
int main(string arg)
{
	string kind = "";
	string type = "";
	int effect_value = 0;
	int timedelay = 0;
	int time_need = 0;
	object me = this_player();
	object room;
	string s = "";
	string room_name = "";
	int flag = 0;
	sscanf(arg,"%s %d",room_name,flag);
	mixed err = catch{
		room = (object)(TEMPLATE_PATH+room_name);
	};
	if(!flag){
		if(me->query_buff(room->query_buff_kind(),0) != "none"){
			s += "您刚已经增加过此类型效果，你确定要覆盖吗？\n";
			s += "[是:exercise "+room_name+" 1] [否:look]\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
	}
	if(!err&&room){
		int times_up = room->query_used_times();//功能房间的使用次数上限
		//无限次使用
		if(!times_up){
			me->exercise(room);
			me->write_view(WAP_VIEWD["/look"]);
		}
		else{
		//有限次使用
			if(me->get_once_day[room->query_name()]&&me->get_once_day[room->query_name()]>=times_up){
			//当天使用次数已经到达上限
				s += "该房间一天只能使用"+times_up+"次，您今天不能再使用\n";
				s += "[返回:popview]\n";
				write(s);
				return 1;
			}
			else{
				this_player()->exercise(room);
				me->get_once_day[room->query_name()] ++;
				this_player()->write_view(WAP_VIEWD["/look"]);
			}
		}
	}
//	else{
//		this_player()->write_view(WAP_VIEWD["/sleep_nobedroom"]);
//	}
	return 1;
}
