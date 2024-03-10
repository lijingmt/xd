#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	object me = this_player();
	string masterId = me->query_name();
	int yushi = 5;
	int rcmTimeDelay = 14;//推荐店铺有效期
	string c_log = "";
	//是否有家园
	if(HOMED->if_have_home(masterId)){
		//是否有店铺
		if(HOMED->if_have_shopLicense(masterId)){
			//是否已经推荐过店铺且还没到期
			string homeId = me->home_path;
			if(!HOMED->if_shop_rcmed(homeId)){
				if(!arg){
					s += "推荐你的店铺：\n";
					s += "\n";
					s += "需要"+YUSHID->get_yushi_for_desc(yushi)+"\n";
					s += "您确定推荐吗?\n";
					s += "[确定:home_shop_recommend_confirm yes] [放弃:home_shop_recommend_confirm no]\n";
					me->write_view(WAP_VIEWD["/emote"],0,0,s);
					return 1;
				}
				if(arg=="no"){
					//放弃推荐
					s += "那你考虑考虑再来吧\n";
					me->write_view(WAP_VIEWD["/emote"],0,0,s);
					return 1;
				}
				//确定推荐店铺
				int result = BUYD->do_trade(me,yushi,0);
				switch(result){
					case 0:
						s += "你身上的玉石不够！\n";
						break;
					case 1:
						s += "你身上的金钱不够！\n";
						break;
					case 2..3:
						HOMED->add_shop_recommend(me,homeId,rcmTimeDelay);//添加推荐店铺
						int cost_reb = yushi;
						c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ masterId +"][home_shop_rcm][sijiaxiaodian][1][1]["+cost_reb+"][0]\n";
						Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
						s += "推荐店铺成功，有效期限为14天\n";
						break;
					default:
						s += "系统犯晕了，请和管理员联系。\n";
				}
			}
			else{
				s += "您推荐的店铺还未过期，没必要浪费钱去重复推荐\n";
			}
		}
		else{
			s += "您没有店铺可推荐\n";
		}
	}
	else{
		s += "您还没有地产，怎么帮您推荐啊，别欺负我老人家～\n";
	}
	s += "\n";
	s += "[返回:home_shop_recommend]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
