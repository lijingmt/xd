#include <globals.h>
#include <mudlib/include/mudlib.h>
//物品中的食品 消耗品，叠加累计
inherit MUD_COMBINE_ITEM;
//具有食品的属性方法和继承关系
inherit MUD_F_EATED;
// 食物是同路径、同效果的纯消耗品；提高的是背包堆叠上限，不改变
// 单次食用效果、商店价格或每日限制。
private string initer=((set_item_type("food")),(max_count=9999),"");
