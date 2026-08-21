#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit WAP_ROOM;

protected void create()
{
	name = object_name(this_object());
	name_cn = "天衡通道";
	desc = "天衡镜光正在确认你的活动节点；确认完成后即可进入候场台。\n";
	set_room_type("timed_event_ingress");
	exits = ([]);
}

string query_timed_event_ingress_id(){ return "tianheng"; }
int is_peaceful(){ return 1; }
// 通道房属于活动世界：下线存档不得把它写进last_pos，否则活动结束后
// 重登会被恢复进已死亡的活动地图（幻境卡人）。
int is_timed_event_room(){ return 1; }

string query_links(void|int count)
{
	return "[继续进入天衡绝境:timed_event join tianheng]\n"+
		"[返回活动页:timed_event]\n";
}

string view_exits(){ return ""; }
