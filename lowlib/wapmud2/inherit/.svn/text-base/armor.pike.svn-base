#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_ARMOR;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;
inherit WAP_F_VIEW_PICTURE;
//特殊任务物品可以重载此方法，变为不可装备状态
string query_inventory_links(void|int count)
{
	if(!equiped){
		return ::query_inventory_links(count)+"[穿戴:wear "+name+" "+count+"]";
	}
	else{
		return ::query_inventory_links(count)+"[脱下:unwear "+name+" "+count+"]";
	}
}
