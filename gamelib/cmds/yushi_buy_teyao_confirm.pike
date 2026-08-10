#include <command.h>
#include <gamelib/include/gamelib.h>
#define TEYAO_PATH ROOT "/gamelib/clone/item/teyao/"
private mapping(string:array(int)) teyao_catalog = ([
	"fenshendan":({1,1,0,0}),
	"huashendan":({1,5,0,0}),
	"huanshendan":({2,1,0,0}),
	"yingzhiwan":({1,5,5,1}),
	"ningliwan":({1,5,5,1}),
	"lingtuwan":({1,5,5,1}),
	"guqidan":({1,5,5,1}),
	"nuhuojiu":({1,2,0,0}),
	"lieyanjiu":({2,1,0,0}),
	"tianhuojiu":({2,2,0,0}),
	"liuxianglu":({1,2,0,0}),
	"xiannvlu":({2,1,0,0}),
	"shennvlu":({2,2,0,0}),
	"jinyulu":({2,7,0,0}),
	"huoninglu":({1,8,0,0}),
	"fengxilu":({1,8,0,0}),
	"bingrongsan":({1,8,0,0}),
	"duxiaosan":({1,8,0,0}),
	"wuweisan":({2,4,0,0}),
]);

private int inventory_amount(object player,string name)
{
	int amount;
	foreach(all_inventory(player),object one)
		if(one && one->query_name()==name)
			amount+=one->is("combine_item") ? (int)one->amount : 1;
	return amount;
}
//确认玉石购买的某药品
//arg =   name       yushi_rareLevel    need_amount       buy_num
//     药品文件名    所需玉石的稀有度   玉石的个数  购买的个数

int main(string|zero arg)
{
	object me = this_player();
	string teyao_name = "";
	int rarelevel = 0;
	int need_amount = 0;
	int need_money = 0;//add by caijie 08/06/10
	int flag = 0;//add by caijie 08/06/10 0表示老的特药 1表示新特药
	int buy_num = 0;
	string s_buy_num = "";
	string s = "";
	string s_log = "";
	string c_log = "";//统计使用的日志 evan added 2008.07.10
	if(!arg || sscanf(arg,"%s %d %d %d %d %s",teyao_name,rarelevel,
	   need_amount,need_money,flag,s_buy_num)!=6 ||
	   !teyao_catalog[teyao_name]){
		write("商品参数无效，本次没有扣除或发放物品。\n"+
			"[返回:yushi_buy_teyao_list exp]\n[返回游戏:look]\n");
		return 1;
	}
	array(int) product=teyao_catalog[teyao_name];
	rarelevel=product[0];
	need_amount=product[1];
	need_money=product[2];
	flag=product[3];
	if(flag==0)
		sscanf(s_buy_num,"no=%d",buy_num);
	else buy_num = 1;
	object teyao;
	string need_yushi = YUSHID->get_yushi_name(rarelevel);
	int yushi_value = YUSHID->get_yushi_value(rarelevel);
	//按总价值换算玩家拥有的指定面额数量
	int have_num = 0;
	if(yushi_value > 0)
		have_num = YUSHID->query_all_num(me)/yushi_value;
	int have_money = me->query_account();
	//计算到玩家能够购买此药的最大个数
	int can_num = 0;
	if(need_amount > 0)
		can_num = have_num/need_amount;
	//由caijie添加于2008/06/10
	if(need_money>0){
		need_money = need_money*100;
		int have_money = me->query_account();
		int m_can_num = have_money/need_money;
		can_num = min(can_num,m_can_num);
	}
	//end
	//必要的判断
	if(buy_num<1 || buy_num>20)
		s += "输入有误！购买个数必须在1到20之间\n";
	else if(can_num<=0 || can_num<buy_num)
		s += "身上玉石或者黄金不够，你无法购买指定数目的此类药品\n";
	else{
		if(flag==1){
			if(me->query_level()>30){
				s += "该特药只对30级以下的玩家销售，你的级别太高，不能购买此药品\n";
				s += "\n";
				s += "[返回:yushi_buy_teyao_list exp]\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			if(me->get_once_day[teyao_name]==1){
				s += "该药品一天只能购买一次\n";
				s += "\n";
				s += "[返回:yushi_buy_teyao_list exp]\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
		}
		mixed err;
		err=catch{
			teyao = clone(TEYAO_PATH+teyao_name);
		};
		if(!err && teyao){
			teyao->amount = buy_num;
			if(me->if_over_load(teyao)){
				s += "你的随身物品已满，无法再装下更多\n";
				destruct(teyao);
			}
			else{
				int cost_reb = need_amount*buy_num*yushi_value;
				int before_wallet=ACCOUNT_WALLETD->query_balance(me);
				int before_physical=YUSHID->query_physical_all_num(me);
				int before_amount=inventory_amount(me,teyao_name);
				if(!YUSHID->pay_yushi(me,cost_reb)){
					s += "玉石扣除失败，请稍后再试\n";
					destruct(teyao);
				}
				else{
					me->del_account(need_money*buy_num);
					string teyao_short=(string)teyao->query_short();
					string teyao_namecn=(string)teyao->query_name_cn();
					teyao->move_player(me->query_name());
					if(inventory_amount(me,teyao_name)-before_amount!=buy_num){
						int added=inventory_amount(me,teyao_name)-before_amount;
						if(added>0)
							me->remove_combine_item_transaction(teyao_name,added);
						me->add_account(need_money*buy_num);
						if(!YUSHID->rollback_yushi_payment(me,before_wallet,
						   before_physical,"teyao_delivery_failed"))
							s += "药品发放和退款异常，请立即联系客服\n";
						else
							s += "药品发放失败，费用已退回\n";
						write(s+"[返回:yushi_buy_teyao_list exp]\n[返回游戏:look]\n");
						return 1;
					}
					s += "交易成功，你获得了"+teyao_short+"\n";
					string consume_time = MUD_TIMESD->get_mysql_timedesc();
					string cost = ""+(need_amount*buy_num)+"|"+need_yushi;
					//s_log += "insert xd_consume (consume_time,user_id,user_name,area,type,cost,get_item,get_item_num,get_item_cn,cost_reb) values ('"+consume_time+"','"+me->query_name()+"','"+me->query_name_cn()+"','"+GAME_NAME_S+"','teyao','"+cost+"','"+teyao_name+"',"+buy_num+",'"+teyao_namecn+"',"+cost_reb+");\n";
					c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][teyao]["+teyao_name+"]["+teyao_namecn+"]["+buy_num+"]["+cost_reb+"]["+flag+"]\n";
					if(flag==1)
						me->get_once_day[teyao_name] = 1;
				}
			}
		}
		else{
			s += "交易失败，无法得到这类药品，请联系游戏版主，我们将尽快为你解决\n";
		}
		/*
		if(s_log != ""){
			string now=ctime(time());
			Stdio.append_file(ROOT+"/log/fee_log/yushi_use-"+MUD_TIMESD->get_year_month_day()+".log",s_log);
		}
		*/
		if(c_log != ""){                                                                           
			Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
		}
	}
	s += "[继续购买:yushi_buy_teyao_list exp]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
