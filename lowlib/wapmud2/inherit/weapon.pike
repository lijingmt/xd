#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_WEAPON;
inherit WAP_F_VIEW_PICTURE;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;
//特殊任务物品可以重载此方法，变为不可装备状态
string query_inventory_links(void|int count)
{
	if(!equiped){
		return ::query_inventory_links(count)+"[装配:wield "+name+" "+count+"]";
	}
	else{
		return ::query_inventory_links(count)+"[放下:unwield "+name+" "+count+"]";
	}
}
string query_extra_links(void|int count)
{
	return "";
}
