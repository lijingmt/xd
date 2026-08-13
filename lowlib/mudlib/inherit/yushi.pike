#include <globals.h>
#include <mudlib/include/mudlib.h>
//收费玉石的基本属性
inherit MUD_COMBINE_ITEM;

//玉石的稀有度
//【玉】碎玉 为1级；【玉】仙缘玉 2级；【玉】玲珑玉 3级；【玉】碧玺玉 4级；【玉】玄天宝玉 5级
protected int yushi_rarelevel = 0;
void set_yushi_rarelevel(int a){yushi_rarelevel=a;}
int query_yushi_rarelevel(){return yushi_rarelevel;}

//玉石等量价值，将于【玉】碎玉为基本单位
//【玉】碎玉 为1；【玉】仙缘玉 10；【玉】玲珑玉 100；【玉】碧玺玉 1000；【玉】玄天宝玉 10000
protected int yushi_value = 0;
void set_yushi_value(int a){yushi_value=a;}
int query_yushi_value(){return yushi_value;}

// 仅五种付费玉提高单组容量；普通道具、药品和特殊炼化石继续使用
// 各自原有上限，面额与合拆比例也不在这里改变。
private string initer=((set_item_type("yushi")),(max_count=9999),"");
