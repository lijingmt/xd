#include <globals.h>
#include <mudlib/include/mudlib.h>
//物品中的武器
inherit MUD_ITEM;
//具有可装备之后的属性方法和继承关系
inherit MUD_F_EQUIP;
//string skill;//物品中的武器上所具有的技能
private string initer=((set_item_type("weapon")),"");
