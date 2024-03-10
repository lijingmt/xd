#include <globals.h>
#include <mudlib/include/mudlib.h>
//物品中的食品 消耗品，叠加累计
inherit MUD_COMBINE_ITEM;
//具有食品的属性方法和继承关系
inherit MUD_F_EATED;
private string initer=((set_item_type("food")),"");
