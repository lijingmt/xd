#include <globals.h>
#include <wapmud2/include/wapmud2.h>

inherit MUD_DECORAT;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;
inherit WAP_F_VIEW_PICTURE;

string query_inventory_links(void|int count)
{
	if(!equiped){
		return ::query_inventory_links(count)+"[´©ÉÏ:wear "+name+" "+count+"]";
	}
	else{
		return ::query_inventory_links(count)+"[ÍÑÏÂ:unwear "+name+" "+count+"]";
	}
}
