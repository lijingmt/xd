#include <command.h>
#include <gamelib/include/gamelib.h>
#define TEYAO_PATH ROOT "/gamelib/clone/item/teyao/"
//确认玉石购买的某药品
//arg =   name       yushi_rareLevel    need_amount       buy_num
//     药品文件名    所需玉石的稀有度   玉石的个数  购买的个数

int main(string arg)
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
	sscanf(arg,"%s %d %d %d %d %s",teyao_name,rarelevel,need_amount,need_money,flag,s_buy_num);
	if(flag==0)
		sscanf(s_buy_num,"no=%d",buy_num);
	else buy_num = 1;
	object teyao;
	string need_yushi = YUSHID->get_yushi_name(rarelevel);
	//获得玩家身上此种玉石的个数
	int have_num = YUSHID->query_yushi_num(me,rarelevel);
	int have_money = me->query_account();
	//计算到玩家能够购买此药的最大个数
	int can_num = have_num/need_amount;
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
			me->get_once_day[teyao_name] = 1;
		}
		mixed err;
		err=catch{
			teyao = clone(TEYAO_PATH+teyao_name);
		};
		if(!err && teyao){
			teyao->amount = buy_num;
			if(me->if_over_load(teyao)){
				s += "你的随身物品已满，无法再装下更多\n";
			}
			else{
				//每购买一个，就扣除一个所消耗的玉石数
				me->remove_combine_item(need_yushi,need_amount*buy_num);
				me->del_account(need_money);
				s += "交易成功，你获得了"+teyao->query_short()+"\n";
				int val = 1;
				if(need_yushi == "xianyuanyu")
					val = 10;
				else if(need_yushi == "linglongyu")
					val = 100;
				else if(need_yushi == "biluanyu")
					val = 1000;
				else if(need_yushi == "xuantianbaoyu")
					val = 10000;
				int cost_reb = need_amount*buy_num*val;
				string teyao_namecn = teyao->query_name_cn();
				string consume_time = MUD_TIMESD->get_mysql_timedesc();
				string cost = ""+(need_amount*buy_num)+"|"+need_yushi;
				//s_log += "insert xd_consume (consume_time,user_id,user_name,area,type,cost,get_item,get_item_num,get_item_cn,cost_reb) values ('"+consume_time+"','"+me->query_name()+"','"+me->query_name_cn()+"','"+GAME_NAME_S+"','teyao','"+cost+"','"+teyao_name+"',"+buy_num+",'"+teyao_namecn+"',"+cost_reb+");\n";
				c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][teyao]["+teyao_name+"]["+teyao_namecn+"]["+buy_num+"]["+cost_reb+"]["+flag+"]\n";
				teyao->move_player(me->query_name());
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
