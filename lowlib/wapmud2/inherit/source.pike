#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_SOURCE;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;
inherit WAP_F_VIEW_PICTURE;
string query_inventory_links(void|int count)
{
	if(this_object()->query_source_type()=="kuang")
		return ::query_inventory_links(count)+"[Œ“Õ⁄:viceskill_dig "+name+" "+count+"]";
	else if(this_object()->query_source_type()=="caoyao")
		return ::query_inventory_links(count)+"[Œ“≤…:viceskill_gather "+name+" "+count+"]";
}
