#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//确认玉石购买的某宝石
//arg =   name       yushi_rareLevel    need_amount       buy_num
//     宝石文件名    所需玉石的稀有度   玉石的个数  购买的个数

int main(string|zero arg)
{
	object me = this_player();
	string yushi_name = "";
	int rarelevel = 0;
	int need_amount = 0;
	int need_money = 0;
	int flag = 0;
	int buy_num = 0;
	string s_buy_num = "";
	string s = "";
	string s_log = "";
	string c_log = "";//统计使用的日志 evan added 2008.07.10
	sscanf(arg,"%s %d %d %d %d %s",yushi_name,rarelevel,need_amount,need_money,flag,s_buy_num);
	if(flag==0)
		sscanf(s_buy_num,"no=%d",buy_num);
	else buy_num = 1;
	object yushi;
	string need_yushi = YUSHID->get_yushi_name(rarelevel);
	int yushi_value = YUSHID->get_yushi_value(rarelevel);
	//按总价值换算玩家拥有的指定面额数量
	int have_num = 0;
	if(yushi_value > 0)
		have_num = YUSHID->query_all_num(me)/yushi_value;
	int have_money = me->query_account();
	//计算到玩家能够购买此宝石的最大个数
	int can_num = 0;
	if(need_amount > 0)
		can_num = have_num/need_amount;
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
		s += "身上玉石不够，你无法购买指定数目的此类宝石\n";
	else{
		mixed err;
		err=catch{
			yushi = clone(YUSHI_PATH+yushi_name);
		};
		if(!err && yushi){
			yushi->amount = buy_num;
			if(me->if_over_load(yushi)){
				s += "你的随身物品已满，无法再装下更多\n";
			}
			else{
				int cost_reb = need_amount*buy_num*yushi_value;
				if(!YUSHID->pay_yushi(me,cost_reb)){
					s += "玉石扣除失败，请稍后再试\n";
				}
				else{
					me->del_account(need_money);
					s += "交易成功，你获得了"+yushi->query_short()+"\n";
					string yushi_namecn = yushi->query_name_cn();
					string consume_time = MUD_TIMESD->get_mysql_timedesc();
					string cost = ""+(need_amount*buy_num)+"|"+need_yushi;
					//s_log += "insert xd_consume (consume_time,user_id,user_name,area,type,cost,get_item,get_item_num,get_item_cn,cost_reb) values ('"+consume_time+"','"+me->query_name()+"','"+me->query_name_cn()+"','"+GAME_NAME_S+"','yushi','"+cost+"','"+yushi_name+"',"+buy_num+",'"+yushi_namecn+"',"+cost_reb+");\n";
					c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][baoshi]["+yushi_name+"]["+yushi_namecn+"]["+buy_num+"]["+cost_reb+"][0]\n";
					yushi->move_player(me->query_name());
				}
			}
		}
		else{
			s += "交易失败，无法得到这类宝石，请联系游戏版主，我们将尽快为你解决\n";
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
	s += "[继续购买:yushi_buy_baoshi_list ronglian]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
