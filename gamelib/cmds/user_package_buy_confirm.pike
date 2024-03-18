#include <command.h>
#include <gamelib/include/gamelib.h>
#define BUY_MAX_COUNT 50
int main(string arg)
{
	object me = this_player();
	string s="";
	string tmp_s = "";
	string s_log = "";
	string type = "";//类型，背包或仓库
	int pac_size = 0;//要扩充的大小
	int need_yushi = 0;//所需要的玉石
	int flag = 0;//购买标志，0：查看  1：确定购买  2:放弃购买
	sscanf(arg,"%s %d %d %d",type,pac_size,need_yushi,flag);
	if(type=="beibao") tmp_s += "背包";
	if(type=="cangku") tmp_s += "仓库";
	if(flag==0){
		s += "您将花费"+YUSHID->get_yushi_for_desc(need_yushi)+"购买1个"+pac_size+"格的"+tmp_s+"\n\n";
		s += "[确认购买:user_package_buy_confirm "+type+" "+pac_size+" "+need_yushi+" 1]\n";
		s += "[再看看:user_package_buy_confirm "+type+" "+pac_size+" "+need_yushi+" 2]\n";
	}
	else if(flag==2){
		s += "那您考虑好了再来吧~\n";
	}
	else if(flag==1){
		if(!me->package_expand[type]){
			me->package_expand[type] = ([]);
		}
		if(BUYD->query_cangku_num(me,type)>=BUY_MAX_COUNT){
			s += "每个玩家最多只能购买"+BUY_MAX_COUNT+"个，您购买的数量已经达到上限.\n";
			if(pac_size>5){
				s += "您可以选择以下替换方式进行购买新的"+tmp_s+"：\n";
				s += "["+tmp_s+"替换:user_package_replace_list "+type+" "+pac_size+"]\n";
			}
			s += "[返回:user_package_buy_list]\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
		int buy_result = BUYD->do_trade(me,need_yushi,0);
		switch(buy_result){
			case 0:
				s += "你身上的玉石不够！\n";
				break;
			case 1:
				s += "你身上的金钱不够！\n";
				break;
			case 2..3:
				if(!me->package_expand[type][pac_size]){
					me->package_expand[type][pac_size]=1;
				}
				else{
					me->package_expand[type][pac_size]+=1;
				}
				string name_cn = pac_size+"格"+tmp_s;
				s_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"]["+type+"]["+pac_size+type+"]["+name_cn+"][1]["+need_yushi+"][0]\n";
				Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",s_log);
				s += "恭喜您成功扩充了"+pac_size+"格"+tmp_s+"\n\n";
				break;
			default:
				s += "系统犯晕了，请和管理员联系。\n";
				break;
		}
	}
	s += "[返回:user_package_buy_list]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
