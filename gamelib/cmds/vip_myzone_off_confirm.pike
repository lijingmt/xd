#include <command.h>
#include <gamelib/include/gamelib.h>
//确认购买打折物品

int main(string arg)
{
	object me = this_player();
	string goods_path= "";
	int lv = 0;
	int price = 0;
	string re = "";
	sscanf(arg,"%s %d %d",goods_path,lv,price);
	array(string) tmp = ({});
	string type = "baoshi";                        //默认的物品类型
	tmp = goods_path/"/";                          //得到文件所在目录，也就是物品的分类
	if(tmp)                                  
	{
		type=tmp[0];
	}
	object goods = clone(ITEM_PATH+goods_path);   //得到商品的相关信息
	string goods_name = goods->query_name();
	goods->set_toVip(1);	
	string goods_namecn = goods->query_name_cn();


	int result = VIPD->if_can_get_offly(me,goods,lv);//判断该玩家是否能获得该物品
	if(result ==4)//可以获得物品
	{
		int trade_result = BUYD->do_trade(me,price,0,1);//交易是否成功
		switch(trade_result){
			case 0:
				re += "你身上的玉石不够！\n";
				break;
			case 1:
				re += "你身上的金钱不够！\n";
				break;
			case 2:
				re += "你身上的空间不够！\n";
				break;
			case 3:
				goods->move_player(me->query_name());
				string c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][vip_off]["+goods_name+"]["+goods_namecn+"][1]["+price+"][0]\n";
				Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
				re += "恭喜，你已经获得了"+ goods_namecn +"\n";
				break;
			default:
				re += "系统犯晕了，请和管理员联系。\n";
				break;
		}
	}
	else
	{
		re += VIPD->if_can_get_offly_desc(result,lv,goods_namecn);
	}

	re += "[继续购买:vip_myzone_off_list "+ type +" "+ lv +"]\n";
	re += "[返回游戏:look]\n";
	write(re);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
