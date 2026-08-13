#include <command.h>
#include <gamelib/include/gamelib.h>
#define INFANCY_PATH ROOT "/gamelib/clone/item/home/infancy/"
//实现玉石购买infancy

int main(string|zero arg)
{
	object me = this_player();
	string infancyName = "";
	int yushi = 0;
	int money = 0;
	string numTmp = "";
	int num = 0;
	string s ="";
	string c_log = "";//统计用的日志
	if(!arg || sscanf(arg,"%s %d %d %s",infancyName,yushi,money,numTmp)!=4){
		write("购买参数无效。\n[返回游戏:look]\n");
		return 1;
	}
	num=SHOP_BATCHD->parse_count(numTmp);
	mapping(string:mixed) offer=HOMED->query_infancy_offer(infancyName);
	if(!(int)offer["ok"] || ((yushi>0)==(money>0))){
		write("商品或支付方式无效。\n[返回游戏:look]\n");
		return 1;
	}
	int payment_kind;
	if(yushi>0){
		payment_kind=1;
		if((int)offer["yushi"]<=0){
			write("该玉石支付方式不可用。\n[返回游戏:look]\n");
			return 1;
		}
	}
	else{
		payment_kind=2;
		if((int)offer["money"]<=0){
			write("该黄金支付方式不可用。\n[返回游戏:look]\n");
			return 1;
		}
	}
	if(num<1 || num>SHOP_BATCHD->query_hard_max())
		s += "输入有误！购买个数必须在1到100之间\n";
	else{
		mapping(string:mixed) result=HOMED->purchase_infancy(me,infancyName,
			num,payment_kind);
		if((int)result["ok"]){
			int cost_reb=(int)result["yushi_cost"];
			c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][home_infancy]["+ (string)result["item_name_cn"] +"]["+num+"][1]["+cost_reb+"][0]\n";
			s += "你获得了"+num+(string)result["unit"]+
				(string)result["item_name_cn"]+"\n";
			s += "[继续购买:home_shop_item_list plant]\n";
		}
		else
			s += (string)result["message"]+"\n";
		if(c_log != "")                                                                           
			Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
