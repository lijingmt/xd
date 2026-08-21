#include <globals.h>
#include <mudlib/include/mudlib.h>
//物品中的书的接口。技能书、配方和图纸内容由文件路径唯一确定，
// 可以安全按同路径叠加；学习成功时只消耗一本，绝不能删除整组。
inherit MUD_COMBINE_ITEM;
//具有书的属性方法和继承
inherit MUD_F_READ;
protected string peifang_type = "";
protected int need_money = 0;
protected int need_yushi = 0;
void set_peifang_type(string s){peifang_type = s;}
string query_peifang_type(){return peifang_type;}
protected string peifang_kind = "";
void set_peifang_kind(string s){peifang_kind = s;}
string query_peifang_kind(){return peifang_kind;}

void set_need_yushi(int s){need_yushi = s;}
int query_need_yushi(){return need_yushi;}

void set_need_money(int s){need_money = s;}
int query_need_money(){return need_money;}

// 696 个历史书本子类都沿用“read_flag 置 0 后调用 remove()”的接口。
// 在基类拦截这个明确的学习成功状态，既不需要批量改写生成文件，也
// 保持普通销毁/清档调用 remove() 时仍然删除整个对象。
void remove(void|int judgement)
{
	if(read_flag==0 && amount>1){
		amount--;
		read_flag=1;
		return;
	}
	::remove(judgement);
}

private string initer=((set_item_type("book")),(max_count=9999),"");
