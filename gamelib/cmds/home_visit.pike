#include <command.h>
#include <gamelib/include/gamelib.h>
#define HOME_MAIN_TEMPLATE ROOT "/gamelib/d/home/template/main"
int main(string|zero arg)
{
	object me = this_player();
	string target = arg ? arg : "";
	object room;
	string previous;
	mixed move_err;
	int moved;
	if(!me || target==""){
		write("要访问谁的家？\n[确认:look]\n");
		return 1;
	}
	if(!LOGICALZONED->can_user_action("home",me->query_name(),target)){
		write("逻辑分区隔离中，无法访问该玩家的家园。\n[确认:look]\n");
		return 1;
	}
	room = HOMED->query_room_by_masterId(target,"main");
	if(room){
		if(!HOMED->move_user_to_home(me,room)){
			write("该家园当前位于其他地图节点，请稍后重试。\n[确认:look]\n");
			return 1;
		}
		me->reset_view(WAP_VIEWD["/home"]);
		me->write_view();
		return 1;
	}
	if(!HOMED->query_home_registered(target)){
		write("他家好像还在装修，稍后再来吧\n\n[确认:look]\n");
		return 1;
	}
	// 家园归属其他Worker：先把门牌号写进 inhome_pos 再走标准跨节点
	// 移动。到达侧由归属Worker按门牌物化真实家园（含犬只货架等
	// 运行态对象），不会再落进空的静态模板房。
	previous = (string)me->query_inhome_pos();
	me->set_inhome_pos(target);
	move_err = catch { moved = me->move(HOME_MAIN_TEMPLATE); };
	if(move_err || !moved){
		me->set_inhome_pos(previous);
		write("通往这个家园的路暂时不通，请稍后再试。\n[确认:look]\n");
		return 1;
	}
	me->reset_view(WAP_VIEWD["/home"]);
	me->write_view();
	return 1;
}
