#include <globals.h>
#include <mudlib/include/mudlib.h>
//物品中的炼金而得的丹药
inherit MUD_COMBINE_ITEM;

//按药的类型分
protected string danyao_kind = "";
void set_danyao_kind(string s){danyao_kind=s;}
string query_danyao_kind(){return danyao_kind;}

//按药的效果分的类型
protected string danyao_type = "";
void set_danyao_type(string s){danyao_type=s;}
string query_danyao_type(){return danyao_type;}

//丹药持续时间
protected int danyao_timedelay = 0;
void set_danyao_timedelay(int a){danyao_timedelay=a;}
int query_danyao_timedelay(){return danyao_timedelay;}

//丹药的作用值
protected int effect_value = 0;
void set_effect_value(int a){effect_value=a;}
int query_effect_value(){return effect_value;}

// 限级追赶药的最高可服用等级；0表示不限制。
protected int danyao_max_level = 0;
void set_danyao_max_level(int a){danyao_max_level=a;}
int query_danyao_max_level(){return danyao_max_level;}

private string initer=((set_item_type("danyao")),"");
