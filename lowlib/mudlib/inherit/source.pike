#include <globals.h>
#include <mudlib/include/mudlib.h>
//物品中的材料源,可能是矿源,花源,等等
inherit MUD_ITEM;
//属性方法和继承关系
//inherit MUD_F_EQUIP;
static string source_type;
void set_source_type(string s){source_type = s;}
string query_source_type(){return source_type;}
private string initer=((set_item_type("source")),"");
