#include <command.h>
#include <gamelib/include/gamelib.h>
//背包替换，只能用小的替换大的
int main(string|zero arg)
{
	object me = this_player();
	string s="";
	string tmp_s = "";
	string s_log = "";
	string s_rep_count = "";//购买数量
	string type = "";//类型，背包或仓库
	int pac_size1 = 0;//替换前的背包大小
	int pac_size2 = 0;//替换后的背包大小
	int need_yushi = 0;//所需要的玉石
	int rep_count = 0;//购买标志，0：查看  1：确定购买  2:放弃购买
	if(!arg || sscanf(arg,"%s %d %d %d %s",type,pac_size1,pac_size2,need_yushi,s_rep_count)!=5 ||
	   (type!="beibao" && type!="cangku")){
		write("替换参数无效。\n[返回游戏:look]\n");
		return 1;
	}
	sscanf(s_rep_count,"no=%d",rep_count);
	int old_price=BUYD->query_pac_price(type,pac_size1);
	int new_price=BUYD->query_pac_price(type,pac_size2);
	need_yushi=new_price-old_price;
	if(old_price<=0 || new_price<=0 || need_yushi<=0 || rep_count<=0 || rep_count>50){
		write("替换规格或数量无效。\n[返回游戏:look]\n");
		return 1;
	}
	if(type=="beibao") tmp_s += "背包";
	if(type=="cangku") tmp_s += "当前角色仓库";
	//werror("------rep_count="+rep_count+"---\n");
	if(me->package_expand && me->package_expand[type] &&
	   me->package_expand[type][pac_size1] &&
	   rep_count<=me->package_expand[type][pac_size1]){
		int yushi = need_yushi*rep_count;
		int buy_result = BUYD->do_trade(me,yushi,0);
		switch(buy_result){
			case 0:
				s += "你身上的玉石不够！\n";
				break;
			case 1:
				s += "你身上的金钱不够！\n";
				break;
			case 2..3:
				if(!me->package_expand[type][pac_size2]){
					me->package_expand[type][pac_size2]=rep_count;
				}
				else{
					me->package_expand[type][pac_size2]+=rep_count;
				}
				me->package_expand[type][pac_size1]-=rep_count;
				if(me->package_expand[type][pac_size1]<=0)m_delete(me->package_expand[type],pac_size1);
				//string name_cn = pac_size+"格"+tmp_s;
				s_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"]["+type+"]["+pac_size1+type+"]["+pac_size2+type+"]["+rep_count+"]["+need_yushi+"][0]\n";
				Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",s_log);
				//s += "您已成功用“p"+rep_count+"pac_size1+"格的"+tmp_s+"替换"+pac_size2+"格的"+tmp_s+"\n\n";
				s += "您已成功用"+rep_count+"个"+pac_size1+"格的"+tmp_s+"替换成"+rep_count+"个"+pac_size2+"格的"+tmp_s+"并且扣除费用"+YUSHID->get_yushi_for_desc(yushi)+"\n\n";
				break;
			default:
				s += "系统犯晕了，请和管理员联系。\n";
				break;
		}
	}
	else {
	//输入的数量大于本身拥有的背包数量
		//s += "您身上没有这么多的"+pac_size1+"格"+tmp_s+"，请重新正确输入\n";
		s += "输入有误，请正确输入\n";
		s += "[重新输入:user_package_replace_detail "+type+" "+pac_size1+" "+pac_size2+" "+need_yushi+"]\n";
		s += "[返回:user_package_replace_list "+type+" "+pac_size2+"]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	s += "[返回:user_package_buy_list]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
