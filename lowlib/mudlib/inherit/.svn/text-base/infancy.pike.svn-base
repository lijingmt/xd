#include <globals.h>
#include <mudlib/include/mudlib.h>
//家园系统中 种子/树苗/矿源 等生长基础物品
inherit MUD_COMBINE_ITEM;


static int homeLevel_limit = 0;//对家园等级的限制
void set_homeLevel_limit(int a){homeLevel_limit=a;}
int query_homeLevel_limit(){return homeLevel_limit;}

static string grownItem_path = "";//使用后在家园中出现的物品路径 （树苗被种之后，在家园中将出现 桃树，该字段就记录了 桃树 对应的文件路径） 
void set_grownItem_path(string a){grownItem_path=a;}
string query_grownItem_path(){return grownItem_path;}

static string harvest_desc = "";//可能收获的物品的说明
void set_harvest_desc(string a){harvest_desc=a;}
string query_harvest_desc(){return harvest_desc;}

//private string initer=((set_item_type("infancy")),"");
