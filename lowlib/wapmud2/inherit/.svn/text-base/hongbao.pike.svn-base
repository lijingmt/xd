#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_BOX;
inherit WAP_F_VIEW_PICTURE;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;

string query_inventory_links(void|int count)
{
	return ::query_inventory_links(count)+"[打开:hb_open "+name+" "+count+" 0 0]\n[用铁剪刀打开:hb_open "+name+" "+count+" 1 1](1碎玉)\n[用银剪刀打开:hb_open "+name+" "+count+" 2 1](1仙缘玉)\n[用金剪刀打开:hb_open "+name+" "+count+" 3 1](1玲珑玉)";
}
string query_extra_links(void|int count)
{
	return "";
}
