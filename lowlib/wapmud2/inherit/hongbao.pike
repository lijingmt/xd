#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_BOX;
inherit WAP_F_VIEW_PICTURE;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;

string query_inventory_links(void|int count)
{
	return ::query_inventory_links(count)+"[��:hb_open "+name+" "+count+" 0 0]\n[����������:hb_open "+name+" "+count+" 1 1](1����)\n[����������:hb_open "+name+" "+count+" 2 1](1��Ե��)\n[�ý������:hb_open "+name+" "+count+" 3 1](1������)";
}
string query_extra_links(void|int count)
{
	return "";
}
