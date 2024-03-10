#include <globals.h>
#include <mudlib/include/mudlib.h>
//物品中的饮料
inherit MUD_COMBINE_ITEM;
//inherit MUD_ITEM;
//具有饮料的属性方法和继承关系
inherit MUD_F_DRINKED;
private string initer=((set_item_type("water")),"");
