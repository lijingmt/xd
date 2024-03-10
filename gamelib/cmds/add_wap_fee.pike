#include <command.h>
#include <gamelib/include/gamelib.h>
//wap捐赠调用接口
int main(string arg)
{
	object me = this_player();
	string s = "";                                                                                            
	//s += "WAP捐赠每次可以为游戏充2块仙缘玉，收费2元/次，每个手机号每天最多WAP捐赠5次，点击确定您将自动退出游戏进入捐赠过程，您是否要继续进行WAP捐赠\n";
	//s += "[url 确定:http://221.130.176.168/fee_ldwy/wap_start.jsp?gameid="+GAME_NAME_S+"&uid="+me->name+"]\n";
	//s += "WAP捐赠暂时停止，请玩家通过短信或者神州行捐赠卡的方式进行捐赠\n"; 
	//s += "由于系统维护，wap捐赠暂停\n";
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
