#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit WAP_ROOM;

// 帮派幻境门房：静态路径形成 bangpai 亲和，跨Worker成员先被路由
// 到此处，再进入按帮派克隆的幻境副本。克隆副本复用本文件布局。
protected void create()
{
	name = object_name(this_object());
	name_cn = "帮派幻境·门房";
	desc = "薄雾笼罩的回廊，尽头隐约传来妖影的低吼。\n"+
		"每周六20:30-21:00，帮派等级4级以上的帮派可入内历练。\n";
	set_room_type("bangpai");
	exits = ([]);
}

int is_peaceful(){ return 1; }
string view_exits(){ return ""; }

/** 克隆副本时改名：按帮派区分显示。 */
void configure_bangpai_illusion_room(int bangid,string bang_name)
{
	name_cn = "帮派幻境·"+(bang_name && bang_name!="" ?
		bang_name : (string)bangid);
	desc = "幻境深处妖影成群，斩杀越多，帮贡与淬炼石越丰。\n"+
		"限时30分钟，奖励按个人击杀数结算。\n";
}

string query_links(void|int count)
{
	object me = this_player();
	if(!me || !(int)me->bangid)
		return "[返回游戏:look]\n";
	return "[进入本帮幻境:bang_illusion enter]\n"+
		"[帮派幻境:bang_illusion]|[返回游戏:look]\n";
}
