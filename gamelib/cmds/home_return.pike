#include <command.h>
#include <gamelib/include/gamelib.h>
#define HOME_MAIN_TEMPLATE ROOT "/gamelib/d/home/template/main"
//玩家传送回家
int main(string|zero arg)
{
	string s = "";
	object me = this_player();
	string my_home = arg ? arg : "";
	string target;
	string previous;
	mixed move_err;
	int moved;
	//开始进入自己的家园
	object|zero room = HOMED->query_home_by_path(arg);
	if(room && !LOGICALZONED->can_user_action("home",
	   me->query_name(),room->query_masterId()))
		room = 0;
	if(room){
		if(!HOMED->move_user_to_home(me,room)){
			write("你的家园当前位于其他地图节点，请稍后重试。\n[确定:look]\n");
			return 1;
		}
		me->reset_view(WAP_VIEWD["/home"]);
		me->write_view();
		return 1;
	}
	// 房间未在本地物化：家园归属其他Worker或确无家园。跨节点回家
	// 与访客同路——先写门牌号再走标准移动重定向。
	target = my_home!="" ? HOMED->query_masterId_by_path(my_home) : "";
	if(target==""){
		my_home = (string)me->query_home_path();
		target = my_home!="" ? HOMED->query_masterId_by_path(my_home) : "";
	}
	if(target!="" && HOMED->query_home_registered(target)){
		previous = (string)me->query_inhome_pos();
		me->set_inhome_pos(target);
		move_err = catch { moved = me->move(HOME_MAIN_TEMPLATE); };
		if(move_err || !moved){
			me->set_inhome_pos(previous);
			write("回家的路暂时不通，请稍后再试。\n[确定:look]\n");
			return 1;
		}
		me->reset_view(WAP_VIEWD["/home"]);
		me->write_view();
		return 1;
	}
	s += "你家的地契出了点问题，房屋已经暂时被官府查封了！\n";
	s += "\n[确定:look]\n";
	write(s);
	return 1;
}
