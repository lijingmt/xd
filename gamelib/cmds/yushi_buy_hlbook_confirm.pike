#include <command.h>
#include <gamelib/include/gamelib.h>


int main(string|zero arg)
{
	object me = this_player();
	string re = "";
	string s_log = "";
	string name = "";
	int requested_yushi = 0;
	object|zero ob = 0;
	string name_cn = "";
	if(!arg || sscanf(arg,"%s %d",name,requested_yushi) != 2 ||
	   !BUYD->can_buy_high_level_book(me,name)){
		re += "\n这本书不在你本职业今日可购买的目录中。\n";
		re += "[返回:yushi_buy_hlbook_list]\n";
		re += "[返回游戏:look]\n";
		write(re);
		return 1;
	}
	int yushi = BUYD->query_high_level_book_price(name);
	if(!BUYD->query_book_num(name)){
		re += "\n该书已售完\n";
		re += "[返回:yushi_buy_hlbook_list]\n";
		re += "[返回游戏:look]\n";
		write(re);
		return 1;
	}
	mixed clone_err = catch {
		ob = clone(ITEM_PATH+name);
	};
	if(clone_err || !ob){
		re += "技能书生成失败，请稍后再试。\n";
		re += "[返回:yushi_buy_hlbook_list]\n";
		re += "[返回游戏:look]\n";
		write(re);
		return 1;
	}
	name_cn = ob->query_name_cn();
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
			s_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][hl_book]["+name+"]["+name_cn+"][1]["+yushi+"][0]\n";
			re += "恭喜，抢购成功，您获得"+name_cn+"\n\n";
			ob->move(me);
			ob = 0;
			BUYD->set_book_num(name,1);
			break;
		default:
			re += "系统犯晕了，请和管理员联系。\n";
			break;
	}
	if(ob)
		destruct(ob);
	if(s_log!=""){
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",s_log);
	}
	re += "[返回:yushi_buy_hlbook_list]\n";
	re += "[返回游戏:look]\n";
	write(re);
	return 1;
}
