#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/" 
//最终合成玉石所调用的指令
//arg = yushi_name rarelevel num
int main(string arg)
{
	string s = "";
	string s_log = "";
	string yushi_name = "";
	string s_num = "";
	int num = 0;
	int rarelevel = 0;
	sscanf(arg,"%s %d %s",yushi_name,rarelevel,s_num);
	sscanf(s_num,"no=%d",num);
	object me = this_player();
	int can_num = YUSHID->query_update_num(me,rarelevel);
	string yushi_namecn = YUSHID->get_yushi_namecn(rarelevel);
	if(num <= 0 || num > 20)
		s += "输入有误，请重新输入,你的输入必须是一个1到20之间的数字\n";
	else if(can_num <= 0)
		s += "合成失败！你没有足够的材料\n";
	else if(num > can_num)
		s += "合成失败！你没有足够的材料来合成你所指定数目的"+yushi_namecn+"\n";
	else{
		//扣减玩家对应材料
		string need_yushi = YUSHID->get_yushi_name(rarelevel-1);
		if(me->if_over_easy_load()){
			s += "你的随身物品已满，已无法再装下更多\n";
		}
		else if(me->query_account()<num*1000){
			s += "合成失败！你已无法支付合成所需的费用\n";
			s_log += "合成失败！无足够的费用";
		}
		else{
			int need_num = me->remove_combine_item(need_yushi,num*10);
			if(need_num == num*10){
				//扣除成功
				object new_yushi;
				mixed err=catch{
					new_yushi = clone(YUSHI_PATH+yushi_name);
				};
				if(!err && new_yushi){
					string now=ctime(time());
					new_yushi->amount = num;
					me->del_account(num*1000);
					s += "合成成功！你获得了"+new_yushi->query_short()+"\n";
					s_log += me->query_name_cn()+"("+me->query_name()+") 将 ("+(num*10)+")"+need_yushi+" 合成为了 ("+num+")"+yushi_name+"\n";
					Stdio.append_file(ROOT+"/log/fee_log/yushi_change-"+MUD_TIMESD->get_year_month()+".log",now[0..sizeof(now)-2]+":"+s_log);
					new_yushi->move_player(me->query_name());
				}
			}
			else
				s += "材料扣除有误！！\n";
		}
	}
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
