#include <command.h>
#include <gamelib/include/gamelib.h>

//购买月饼礼盒
int main(string|zero arg)
{
	object me = this_player();
	string re = "";
	string s_log = "";
	string name = "";
	int yushi = 0;
	if(!arg || sscanf(arg,"%s %d",name,yushi)!=2 ||
	   name!="baoxiang/yuebinglihe"){
		write("商品参数无效，本次没有扣除或发放物品。\n"+
			"[返回:yblh_buy_detail]\n[返回游戏:look]\n");
		return 1;
	}
	yushi=20;
	object ob;
	mixed clone_err=catch{
		ob=clone(ITEM_PATH+name);
	};
	if(clone_err || !ob){
		write("礼盒暂时无法生成，本次没有扣除玉石。\n"+
			"[返回:yblh_buy_detail]\n[返回游戏:look]\n");
		return 1;
	}
	int trade_result = BUYD->do_trade(me,yushi,0,1);
	switch(trade_result){
		case 0:
			re += "你身上的玉石不够！\n";
			destruct(ob);
			break;
		case 1:
			re += "你身上的金钱不够！\n";
			destruct(ob);
			break;
		case 2:
			re += "您的背包已满，不能再装下其它的东西\n";
			destruct(ob);
			break;
		case 3:
			string name_cn = ob->query_name_cn();
			s_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][yblh]["+name+"]["+name_cn+"][1]["+yushi+"][0]\n";
			re += "中秋节快乐~，您获得了高级"+name_cn+"\n\n";
			ob->move(me);
			break;
		default:
			re += "系统犯晕了，请和管理员联系。\n";
			if(ob)
				destruct(ob);
			break;
	}
	if(s_log!=""){
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",s_log);
	}
	re += "[继续购买:yblh_buy_detail]\n";
	re += "[返回游戏:look]\n";
	write(re);
	return 1;
}
