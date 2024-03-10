#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//神州行捐赠卡购买说明
int main(string arg)
{
	object me = this_player();
	string s = "";
	s += "用户捐赠50元，即可获得5颗玲珑玉\n";
	s += "捐赠联络qq:1811117272\n";
	/*s += me->query_mini_picture_url("decorate11")+"神州行卡捐赠获取仙玉说明\n";
	s += "[url 直接捐赠:http://221.130.176.168/wap_szx/order.jsp?gameid="+GAME_NAME_S+"&uid="+me->name+"]\n";
	s += "神州行捐赠卡每次可以为游戏用户捐赠5颗玲珑玉，固定收费50元/次。\n\n";
	s += "※特别提醒：\n";
	s += "1.神州行捐赠玉石只支持50元面额的神州行捐赠卡捐赠。如果玩家使用其它面额捐赠卡进行捐赠操作，导致出现卡面金额与玉石数量不相符合的情况，官方将不予处理。\n";
	s += "2.所有手机卡用户均可使用该功能（不局限于神州行用户）。\n";
	s += "3.捐赠成功以前请保留捐赠卡，以防出现捐赠不成功而投诉查询。\n\n";
	
	s += "※操作说明：\n";
	s += "1.提示页面后，在对应输入框内输入捐赠卡序列号及捐赠密码并提交。\n";
	s += "2.捐赠等待过程可能持续较长时间，在这期间不影响游戏中的任何操作，15分钟以后您可以在游戏人物道具中查看玉石是否到帐，如未到帐请拨打官方客服电话010-58621742进行查询。\n";
	*/
	//s += "[url 直接捐赠:http://221.130.176.168/wap_szx/order.jsp?gameid="+GAME_NAME_S+"&uid="+me->name+"]\n";
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
