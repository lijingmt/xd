#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//玉石玩家操作接口
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += me->query_mini_picture_url("1taomujian")+"**使用玉石**\n";
	s += me->query_mini_picture_url("1taomujian")+"[仙道会员店:vip_myshop]\n";
	//s += me->query_mini_picture_url("decorate9")+"[幸运抽抽:lottery_view_list]\n";
	s += me->query_mini_picture_url("1taomujian")+"[仙玉特卖场:yushi_spec_sales]\n";
	s += me->query_mini_picture_url("1taomujian")+"[玉石操作:yushi_change]\n";
	
	s += me->query_mini_picture_url("1taomujian")+"**捐赠获取玉石**\n";
	s += me->query_mini_picture_url("1taomujian")+"[捐赠获取仙玉:add_szx_fee]\n";
	s += me->query_mini_picture_url("1taomujian")+"[其他方式购买:add_else_fee]\n";
	
	s += me->query_mini_picture_url("1taomujian")+"**玉石说明**\n";
	s += me->query_mini_picture_url("1taomujian")+"[玉石说明:yushi_explain]\n";
	//s += me->query_mini_picture_url("1taomujian")+"[捐赠获取玉石说明:yushi_readme]\n";
	s += me->query_mini_picture_url("1taomujian")+"[炼化装备说明:convert_readme]\n";
	s += "\n[返回游戏:look]\n";
	write(s);
	return 1;
}
