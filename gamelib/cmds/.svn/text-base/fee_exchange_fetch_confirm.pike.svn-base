#include <command.h>
#include <gamelib/include/gamelib.h>
//完成领取兑换来的筹码的指令
//arg = id from_game 
//兑换id 来自游戏区的代号
int main(string arg)
{
	object me = this_player();
	int id;
	string from_game = "";
	string s = "";
	sscanf(arg,"%d %s",id,from_game);
	if(me->get_once_day["fee_from_qp"]){
		s += "从棋牌兑换过来的货币，每个帐号每天只能领取一次\n";
		tell_object(me,s);
		me->command("fee_exchange_fetch_list");
		return 1;
	}
	int rtn_fg = FEE_EXCHANGED->fetch_fee(me,id,from_game);
	//rtn_fg = 1表示领取成功，=0表示已经领取过了，=-1表示没有这条记录
	if(rtn_fg > 0){
		s += "领取成功！你得到了"+YUSHID->query_yushi_add_fee_desc(rtn_fg,1)+"\n";
		me->get_once_day["fee_from_qp"]=1;
	}
	else if(rtn_fg == 0){
		s += "领取失败！这笔兑换你已经领取过\n";
	}
	else if(rtn_fg == -1){
		s += "领取失败！没有这笔兑换的记录\n";
	}
	tell_object(me,s);
	me->command("fee_exchange_fetch_list");
	return 1;
}
