#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_DANYAO;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;
inherit WAP_F_VIEW_PICTURE;
string query_inventory_links(void|int count)
{
		return ::query_inventory_links(count)+"[ ≥”√:viceskill_eat_danyao "+name+" "+count+" 0 0]";
}
