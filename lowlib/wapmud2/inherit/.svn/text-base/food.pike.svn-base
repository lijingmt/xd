#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_FOOD;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;
inherit WAP_F_VIEW_PICTURE;
string query_inventory_links(void|int count)
{
	return ::query_inventory_links(count)+"[³Ô:eat "+name+" "+count+"]";
}
