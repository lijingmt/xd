#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/" 
//最终合成玉石所调用的指令
//arg =         yushi_name            rarelevel                      num
//        打碎后得到的玉石文件名   得到的玉石的稀有度      玩家指定的被打碎玉石的个数
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
	int can_num = YUSHID->query_degrade_num(me,rarelevel);
	string yushi_namecn = YUSHID->get_yushi_namecn(rarelevel);
	string need_namecn = YUSHID->get_yushi_namecn(rarelevel+1);
	if(num <= 0 || num > 5)
		s += "输入有误，请重新输入,你的输入必须是1到5之间的数字\n";
	else if(can_num <= 0)
		s += "打碎失败！你没有足够的"+need_namecn+"\n";
	else if(num > can_num)
		s += "打碎失败！你没有你所指定数目的"+need_namecn+"\n";
	else{
		//扣减玩家对应材料
		string need_yushi = YUSHID->get_yushi_name(rarelevel+1);
		//int need_num = me->remove_combine_item(need_yushi,num);
		if(num){
		//扣除成功
			s_log += me->query_name_cn()+"("+me->query_name()+") 打算打碎("+num+")"+need_yushi+",结果为:";
			object new_yushi;
			int i = num*10/30;//得到完整的组数
			int j = (num*10)%30;//得到不足一组的个数
			mixed err;
			for(int k=1;k<=i;k++){
				err=catch{
					new_yushi = clone(YUSHI_PATH+yushi_name);
				};
				if(!err && new_yushi){
					if(me->if_over_easy_load()){
						s += "打碎失败！你的随身物品已满\n";
						s_log += "打碎失败！随身物品已满";
						break;
					}
					else if(me->query_account()<3000){
						s += "打碎失败！你已无法支付所需费用\n";
						s_log += "打碎失败！无足够的费用";
						break;
					}
					else{
						new_yushi->amount = 30;
						me->del_account(3000);
						me->remove_combine_item(need_yushi,3);
						s += "打碎成功！你获得了"+new_yushi->query_short()+"\n";
						s_log += " 将(3)"+need_yushi+"打碎获得(30)"+yushi_name+",";
						new_yushi->move_player(me->query_name());
					}
				}
			}
			if(j>0){
				int money = 1000;
				err=catch{
					new_yushi = clone(YUSHI_PATH+yushi_name);
				};
				if(j>10) money = 2000;
				if(!err && new_yushi){
					new_yushi->amount = j;
					if(me->if_over_load(new_yushi)){
						s += "打碎失败！你的随身物品已满\n";
						s_log += "打碎失败！随身物品已满";
					}
					else if(me->query_account()<money){
						s += "打碎失败！你已无法支付所需费用\n";
						s_log += "打碎失败！随身物品已满";
					}
					else{
						me->del_account(money);
						me->remove_combine_item(need_yushi,1);
						s += "打碎成功！你获得了"+new_yushi->query_short()+"\n";
						if(j>10)
							s_log += " 将(2)"+need_yushi+"打碎获得("+j+")"+yushi_name+",";
						else
							s_log += " 将(1)"+need_yushi+"打碎获得("+j+")"+yushi_name+",";
						new_yushi->move_player(me->query_name());
					}
				}

			}
			if(s_log != ""){
				string now=ctime(time());
				Stdio.append_file(ROOT+"/log/fee_log/yushi_change-"+MUD_TIMESD->get_year_month()+".log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
		}
		else
			s += "材料扣除有误！！\n";
	}
	s += "\n[返回:yushi_myzone.pike]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
