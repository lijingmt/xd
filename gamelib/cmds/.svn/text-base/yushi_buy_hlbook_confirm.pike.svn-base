#include <command.h>
#include <gamelib/include/gamelib.h>


int main(string arg)
{
	object me = this_player();
	string re = "";
	string s_log = "";
	string name = "";
	int yushi = 0;
	sscanf(arg,"%s %d",name,yushi);
	if(!BUYD->query_book_num(name)){
		re += "\n该书已售完\n";
		re += "[返回:yushi_buy_hlbook_list]\n";
		re += "[返回游戏:look]\n";
		write(re);
		return 1;
	}
	int trade_result = BUYD->do_trade(me,yushi,0,1);
	switch(trade_result){
		case 0:
			re += "你身上的玉石不够！\n";
			break;
		case 1:
			re += "你身上的金钱不够！\n";
			break;
		case 2:
			re += "您的背包已满，不能再装下其它的东西\n";
			break;
		case 3:
			object ob = clone(ITEM_PATH+name);
			string name_cn = ob->query_name_cn();
			s_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][hl_book]["+name+"]["+name_cn+"][1]["+yushi+"][0]\n";
			re += "恭喜，抢购成功，您获得"+name_cn+"\n\n";
			ob->move(me);
			BUYD->set_book_num(name,1);
			break;
		default:
			re += "系统犯晕了，请和管理员联系。\n";
			break;
	}
	if(s_log!=""){
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",s_log);
	}
	re += "[返回:yushi_buy_hlbook_list]\n";
	re += "[返回游戏:look]\n";
	write(re);
	return 1;
}
