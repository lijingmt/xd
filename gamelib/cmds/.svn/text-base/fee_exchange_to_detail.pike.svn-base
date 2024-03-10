#include <command.h>
#include <gamelib/include/gamelib.h>
//进入兑换到某游戏区功能页的指令，这里提供出量限制，提供玩家输入帐号和兑换金额
//arg = 游戏区代码
int main(string arg)
{
	object me = this_player();
	string game_id = arg;
	string to_game_cn = FEE_EXCHANGED->query_to_game_cn(game_id);
	string s = "你选择用仙缘玉兑换成"+to_game_cn+"的筹码\n";
	s += "【注意】：15级(包括15级)以下的玩家不能兑换筹码\n";
	s += "【注意】：每个玩家最多只能兑换100仙缘玉\n";
	s += "兑换比例：1仙缘玉 = 1000筹码\n";
	s += "请输入兑换给"+to_game_cn+"的玩家帐号：\n";
	s += "请输入正确且存在的账号，以免对方无法获得（注意：输入帐号为棋牌的注册帐号）\n";
	s += "[string tn:...]\n";
	s += "请输入要兑换的仙缘玉个数：\n";
	s += "[int fe:...]\n";
	s += "[submit 确定:fee_exchange_to_confirm 0 "+game_id+" ...]\n";
	s += "你目前拥有【玉】仙缘玉："+YUSHID->query_yushi_num(me,2)+"\n";
	s += "--------\n";
	string game_tmp = game_id[0..1];
	s += "[返回:fee_exchange_list]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
