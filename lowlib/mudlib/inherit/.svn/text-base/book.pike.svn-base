#include <globals.h>
#include <mudlib/include/mudlib.h>
//物品中的书的接口
inherit MUD_ITEM;
//具有书的属性方法和继承
inherit MUD_F_READ;
static string peifang_type = "";
static int need_money = 0;
static int need_yushi = 0;
void set_peifang_type(string s){peifang_type = s;}
string query_peifang_type(){return peifang_type;}
static string peifang_kind = "";
void set_peifang_kind(string s){peifang_kind = s;}
string query_peifang_kind(){return peifang_kind;}

void set_need_yushi(int s){need_yushi = s;}
int query_need_yushi(){return need_yushi;}

void set_need_money(int s){need_money = s;}
int query_need_money(){return need_money;}                                                                                   

private string initer=((set_item_type("book")),"");
