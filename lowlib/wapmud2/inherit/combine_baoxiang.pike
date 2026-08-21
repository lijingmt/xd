#include <globals.h>
#include <wapmud2/include/wapmud2.h>

// 圣诞宝箱专用叠加基类。普通宝箱继续使用 WAP_BAOXIANG，避免改变
// 精金宝箱、宝石袋和月饼礼盒的历史存档及开启语义。
inherit WAP_COMBINE_ITEM;

private string initer=((set_item_type("box")),(max_count=9999),"");

string query_inventory_links(void|int count)
{
	return ::query_inventory_links(count)+
		"[打开1个:bx_open "+name+" "+(string)count+" 1]"+
		"[批量打开（最多20个）:bx_open "+name+" "+(string)count+" 20]";
}

string query_extra_links(void|int count)
{
	return "";
}
