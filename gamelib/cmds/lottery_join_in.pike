//玩家参与抽奖的指令
//arg = lv 抽奖的级别，!arg则表示全范围抽奖
//这里需要对抽奖作出条件判断：1.玩家身上有足够的玉石，2.仍有抽奖次数
#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	int lv;
	if(arg)
		lv = (int)arg;
	else
		lv = LOTTERYD->get_random_lottery_level();
	//获得玩家身上玉石的个数
	int have_num = YUSHID->query_yushi_num(me,1);
	int need_num = LOTTERYD->get_lottery_award_price(lv);
	if(!lv){
		s += "操作失败！奖项已全部抽完，请等待下次抽奖\n";
	}
	else if(have_num < need_num){
		s += "操作失败！需要"+need_num+"碎玉，你身上没有足够的玉石\n";
	}
	else if(LOTTERYD->get_lottery_award_left(lv) <= 0){
		s += "操作失败！此级别的奖品已被抽完，请等待下一轮或选择其他级别的奖项\n";
	}
	else{
		int luck_num = LOTTERYD->get_lottery_award_luck_num(lv);
		int get_num = LOTTERYD->player_get_num(me,lv);
		int remove_fg = -1;//0 返回玉石; 1 中奖; 2 特药奖励
		int award_num = LOTTERYD->get_lottery_award_amount(lv);
		int cost_reb;
		string log_flag = get_num+"-"+luck_num;
		string award_name = LOTTERYD->get_lottery_award_name(lv);
		string award_namecn = LOTTERYD->get_lottery_award_namecn(lv);
		if(get_num != luck_num){
			s += "(T_T)你抽的号为"+get_num+"，未能中奖\n";
			int r = random(100);
			int yu_r = 30;//返玉概率
			if(r<yu_r){
				s += "作为鼓励，"+need_num+"碎玉返还于你\n";
				remove_fg = 0;
			}
			//对不同等奖有一定机率获得特药奖励 cai 080806
			else {
				int rw_r = LOTTERYD->get_reward_range(lv);//获得特药的概率
				if(r<(yu_r + rw_r)){
					object rw_ob = LOTTERYD->get_reward_ob(lv);//获取特药
					if(rw_ob){
						string rw_name = rw_ob->query_short();
						rw_ob->move_player(me->query_name());
						remove_fg = 2;
						s += "作为鼓励，您获得了"+rw_name+",继续加油吧，也许"+lv+"等奖就是您的了-[随身物品:inventory]\n";
					}
					else 
						s += "这奖品好像有点问题\n";
				}
			}
			//end cai 080806
		}
		else{
			award_name = LOTTERYD->get_lottery_award_name(lv);
			if(award_name != ""){
				object award;
				mixed err = catch{
					award = clone(ITEM_PATH+award_name);
				};
				if(!err && award){
					award_num = LOTTERYD->get_lottery_award_amount(lv);
					award_namecn = LOTTERYD->get_lottery_award_namecn(lv);
					s += "(^0^)你抽的号为"+get_num+"，恭喜你！你中了"+lv+"等奖\n";
					s += "你获得了"+award_namecn+"x"+award_num+"-[随身物品:inventory]\n";
					if(award->is_combine_item()){
						award->amount = award_num;
						award->move_player(me->query_name());
					}
					else
						award->move(me);
					remove_fg = 1;
					//广播
					string notice_s = "【抽抽大广播】";
					switch(lv){
						case 1:
							notice_s += "一等奖！一等奖！"+me->query_name_cn()+"中了"+lv+"等奖，这一刻他仿佛灵魂附体\n";
							break;
						case 2:
							notice_s += "不会吧！二等奖又少了一个！"+me->query_name_cn()+"居然得到了它\n";
							break;
						case 3:
							notice_s += me->query_name_cn()+"今天很幸运的样子，三等奖！继续加油吧\n";
							break;
						case 4:
							notice_s += me->query_name_cn()+"中了四等奖！未来在你手中，恩，努力！\n";
							break;
						case 5:
							notice_s += "五等奖也是奖，我们也要榜一榜！"+me->query_name_cn()+"，恭喜你\n";
							break;
						default:
							notice_s += "没有广播就是好广播\n";
							break;
					}
					CITYD->notice_update(notice_s);
				}
				else
					s += "操作失败！看来奖品出了点问题\n";
			}
		}
		//扣除玩家身上的玉石
		if(remove_fg){
			cost_reb = need_num;
			me->remove_combine_item("suiyu",2);
		}
		string c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"][lottery]["+award_name+"]["+award_namecn+"]["+award_num+"]["+cost_reb+"]["+log_flag+"]\n";
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
	}
	tell_object(me,s);
	if(arg)
		me->command("lottery_view_detail "+lv);
	else
		me->command("lottery_view_list");
	return 1;
}
