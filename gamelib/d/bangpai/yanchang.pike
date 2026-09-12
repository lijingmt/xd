#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit WAP_ROOM;

// 帮派演武场：全部帮派BOSS共用的封闭场地。路径块 bangpai 形成单一
// 亲和键，跨Worker时成员进入会自动收敛到持有BOSS的Worker。
protected void create()
{
	name = object_name(this_object());
	name_cn = "帮派演武场";
	desc = "四壁悬挂各帮战旗，中央是供镇帮神兽降临的巨大法阵。\n"+
		"召唤帮派BOSS后，全帮成员可在此协力助战。\n";
	set_room_type("bangpai");
	exits = ([]);
}

int is_peaceful(){ return 1; }
string view_exits(){ return ""; }

string query_links(void|int count)
{
	return BANGPAI_EXTD->query_bang_boss_arena_links(this_player());
}
