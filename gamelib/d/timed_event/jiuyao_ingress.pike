#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit WAP_ROOM;

protected void create()
{
	name = object_name(this_object());
	name_cn = "九曜通道";
	desc = "九曜阵纹正在确认你的活动节点；确认完成后即可进入集结台。\n";
	set_room_type("timed_event_ingress");
	exits = ([]);
}

string query_timed_event_ingress_id(){ return "jiuyao"; }
int is_peaceful(){ return 1; }

string query_links(void|int count)
{
	return "[继续进入九曜镇渊:timed_event join jiuyao]\n"+
		"[返回活动页:timed_event]\n";
}

string view_exits(){ return ""; }
