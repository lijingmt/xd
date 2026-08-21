#include <globals.h>
#include <mudlib/include/mudlib.h>
//鐗╁搧涓殑楗枡
inherit MUD_COMBINE_ITEM;
//inherit MUD_ITEM;
//鍏锋湁楗枡鐨勫睘鎬ф柟娉曞拰缁ф壙鍏崇郴
inherit MUD_F_DRINKED;
// 饮品是同路径、同效果的纯消耗品；提高的是背包堆叠上限，不改变
// 单次饮用效果、商店价格或每日限制。
private string initer=((set_item_type("water")),(max_count=9999),"");
