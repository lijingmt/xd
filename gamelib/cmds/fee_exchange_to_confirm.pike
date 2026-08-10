#include <command.h>
#include <gamelib/include/gamelib.h>
//该指令完成向其他游戏区兑换的功能，判断条件：自身拥有足够数量的货币，在出入量限制之内
//arg = fg to_game 输入的内容
int main(string|zero arg)
{
	object me = this_player();
	int fg;
	int ante_fee;
	string to_game = "";
	string to_user = "";
	string s = "";
	string arg_tail = "";
	if(!arg || sscanf(arg,"%d %s tn=%s fe=%d",fg,to_game,to_user,ante_fee)!=4 ||
	   (fg!=0 && fg!=1) || to_game!="qp0" || ante_fee<=0 || ante_fee>100){
		write("兑换参数无效。\n[返回:fee_exchange_to_list]\n[返回游戏:look]\n");
		return 1;
	}
	sscanf(arg,"%d %s",fg,arg_tail);
	to_user = filter_msg(to_user);
	if(sizeof(to_user)<2 || sizeof(to_user)>11 || check_name(to_user) == 0)
		s += "您输入的帐号有误，请确认后重新输入\n";
	else if(ante_fee <= 0)
		s += "您输入的兑换数不正确，请确认后重新输入\n";
	else if(me->query_level()<=15)
		s += "您的级别不够，兑换筹码必须要高于15级的玩家才能兑换\n";
	else if(me->get_once_day["fee_to_qp"]){
		s += "每个帐号每天只能兑换一次游戏币\n";
	}
	else{
		int ante_real = ante_fee*10;
		if(YUSHID->query_yushi_num(me,2)<ante_fee){
			s += "你身上没有这么多的玉石\n";
			tell_object(me,s);
			me->command("fee_exchange_to_detail "+to_game);
			return 1;
		}
		if(ante_fee>100)
			s += "每个玩家每天只能兑换100个仙缘玉\n------\n";
		else{
			if(!fg){
				string to_game_cn = FEE_EXCHANGED->query_to_game_cn(to_game);
				s += "此次兑换信息如下：\n";
				s += "兑换到区："+to_game_cn+"\n";
				s += "兑换到帐号："+to_user+"\n";
				s += "兑换数量："+ante_fee+"仙缘玉等值\n";
				s += "--------\n";
				s += "确保无误后点击确认完成兑换、\n";
				s += "[确认:fee_exchange_to_confirm 1 "+arg_tail+"]\n";
				s += "[重新输入:fee_exchange_to_detail "+to_game+"]\n";
			}
			else{
				int old_once=(int)me->get_once_day["fee_to_qp"];
				mapping(string:mixed) removal=
					me->remove_combine_item_transaction("xianyuanyu",ante_fee);
				if(!(int)removal["ok"]){
					write("兑换失败！仙缘玉扣除未完成。\n[返回游戏:look]\n");
					return 1;
				}
				me->get_once_day["fee_to_qp"]=1;
				if(!me->save_with_result()){
					me->get_once_day["fee_to_qp"]=old_once;
					me->rollback_combine_item_transaction(removal);
					write("人物存档失败，仙缘玉没有兑换。\n[返回游戏:look]\n");
					return 1;
				}
				int rtn = FEE_EXCHANGED->exchange_to(me,to_game,to_user,ante_real);
				if(rtn){
					s += "兑换成功！对方账号可在兑换的领取处领取\n";
				}
				else{
					me->get_once_day["fee_to_qp"]=old_once;
					me->rollback_combine_item_transaction(removal);
					if(!me->save_with_result())
						werror("[FEE-EXCHANGE] 严重: 兑换失败后人物回滚落盘失败 player=%s amount=%d\n",
							(string)me->query_name(),ante_fee);
					s += "兑换失败！无法完成这笔交易\n";
				}
			}
			s += "[返回:fee_exchange_to_list]\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
	}
	tell_object(me,s);
	me->command("fee_exchange_to_detail "+to_game);
	return 1;
}

string filter_msg(string|zero arg)
{
	if(!arg)
		return "";
	arg=replace(arg,"'","‘");
	arg=replace(arg,",","，");
	arg=replace(arg,".","。");
	arg=replace(arg,"@","。");
	arg=replace(arg,"#","。");
	arg=replace(arg,"%","。");
	arg=replace(arg,"~","。");
	arg=replace(arg,"^","。");
	arg=replace(arg,"$","。");
	arg=replace(arg,"+","。");
	arg=replace(arg,"|","。");
	arg=replace(arg,"&","。");
	arg=replace(arg,"=","＝");
	arg=replace(arg,"(","（");
	arg=replace(arg,")","）");
	arg=replace(arg,"-","－");
	arg=replace(arg,"_","－");
	arg=replace(arg,"*","－");
	arg=replace(arg,"?","？");
	arg=replace(arg,"!","！");
	arg=replace(arg,"<","－");
	arg=replace(arg,">","－");
	arg=replace(arg,"\/","“");
	arg=replace(arg,"\"","“");
	arg=replace(arg,"\\","“");
	arg=replace(arg,"\r\n","");
	arg=replace(arg,":","：");
	arg=replace(arg,";","；");
	arg=replace(arg,"\{","「");
	arg=replace(arg,"\}","「");
	arg=replace(arg,"[","「");
	arg=replace(arg,"]","」");
	arg=replace(arg,"%20","－");	
	return arg;
}
int check_name(string user_name){
	for(int i=0;i<sizeof(user_name);i++){
		if( user_name[i]>='a'&&user_name[i]<='z'||user_name[i]>='A'&&user_name[i]<='Z'||user_name[i]>='0'&&user_name[i]<='9')
			;
		else{
			return 0;
		}
	}
	return 1;
}
