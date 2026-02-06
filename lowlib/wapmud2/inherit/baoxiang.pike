#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_BOX;
inherit WAP_F_VIEW_PICTURE;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;

string query_inventory_links(void|int count)
{
	return ::query_inventory_links(count)+"[打开:bx_open "+name+" "+count+"]";
}
string query_extra_links(void|int count)
{
	return "";
}
