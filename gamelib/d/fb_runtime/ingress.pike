#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit WAP_ROOM;

protected void create()
{
	name=object_name(this_object());
	name_cn="幻境中转通道";
	desc="幻境阵纹正在把同一队伍汇聚到唯一地图节点；确认后即可继续进入。\n";
	set_room_type("fb_worker_ingress");
	exits=([]);
}

int is_fb_worker_ingress(){ return 1; }
int is_peaceful(){ return 1; }

string query_links(void|int count)
{
	object player=this_player();
	string fb_name=player ? FBD->query_fb_name_by_id(player->fb_id) : "";
	if(fb_name=="")
		return "[安全返回:fb_leave]\n";
	return "[继续进入幻境:fb_entry "+fb_name+" 0 0]\n"+
		"[安全返回入口:fb_leave "+fb_name+"]\n";
}

string view_exits(){ return ""; }
