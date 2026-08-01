#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name count flag
//吃丹药时调用的指令
int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	string name = "";
	int count = 0;
	int flag = 0;
	string now=ctime(time());
	int d_flag = 0;//add by caijie
	sscanf(arg,"%s %d %d %d",name,count,flag,d_flag);
	object ob=present(name,me,count);
	if(ob && me == environment(ob)){
		string kind = ob->query_danyao_kind();
		int max_level = ob->query_danyao_max_level();
		if(max_level>0 && me->query_level()>max_level){
			s += ob->query_name_cn()+"只供"+max_level+"级及以下玩家追赶等级使用；你已达到"+me->query_level()+"级，无法继续服用。\n";
		}
		else if(flag == 0){
			if(me->query_buff(kind,0) != "none"){
				if(d_flag==0){
					s += "你身上已经有此类药的效果，是否仍要食用？食用后会将现在的效果覆盖掉\n";
					s += "[是:viceskill_eat_danyao "+name+" "+count+" 1 0] [否:inventory]\n";
				}
				else if(d_flag==1){
					s += "你身上已经有此类效果，是否仍要阅读？阅读后会将现在的效果覆盖掉\n";
					s += "[是:viceskill_eat_danyao "+name+" "+count+" 1 1] [否:inventory]\n";
				}
			}
			else{
				int eat = LIANDAND->eat_danyao(me,ob);
				//eat_danyao()返回1成功、2超过每日次数、3超过药品等级限制
				if(eat == 2){
					s += "你已经达到每天的食用次数限制(当前最大次数："+me->query_max_yao()+")，无法再食用此类药品\n";
					s += me->query_max_yao_info();//会员最大食用药数说明
				}
				else if(eat == 3){
					s += "你的等级已经超过该药品的使用上限，药品没有被消耗。\n";
				}
				else if(eat == 1){
					if(kind == "te_exp" || kind == "te_honer" || kind == "te_luck" || kind == "te_attack" || kind == "te_vice" || kind == "te_defend" || kind =="te_base"){
						string now=ctime(time());
						string s_log = me->query_name_cn()+"("+me->query_name()+") 食用了 (1)"+ob->query_name_cn()+"\n";
						Stdio.append_file(ROOT+"/log/fee_log/teyao_eat-"+MUD_TIMESD->get_year_month()+".log",now[0..sizeof(now)-2]+":"+s_log+"\n");
					}
					//s += "你食用了"+ob->query_name_cn()+"。\n";
					if(d_flag==0){
						s += "你食用了"+ob->query_name_cn()+"。\n";
					}
					else if(d_flag==1){
						s += "你阅读了"+ob->query_name_cn()+"。\n";
					}
					me->remove_combine_item(ob->query_name(),1);
				}
			}
		}
		else if(flag == 1){
			int eat = LIANDAND->eat_danyao(me,ob);
			if(eat == 2){
				s += "你已经达到每天的食用次数限制，无法再食用此类药品\n";
			}
			else if(eat == 3){
				s += "你的等级已经超过该药品的使用上限，药品没有被消耗。\n";
			}
			else if(eat == 1){
				if(kind == "te_exp" || kind == "te_honer" || kind == "te_luck" || kind == "te_attack" || kind == "te_vice" || kind == "te_defend" || kind == "te_base"){
					string now=ctime(time());
					string s_log = me->query_name_cn()+"("+me->query_name()+") 食用了 ("+ob->amount+")"+ob->query_name_cn()+"\n";
					Stdio.append_file(ROOT+"/log/fee_log/teyao_eat-"+MUD_TIMESD->get_year_month()+".log",now[0..sizeof(now)-2]+":"+s_log+"\n");
				}
				//s += "你食用了"+ob->query_name_cn()+"。\n";
				if(d_flag==0){
					s += "你食用了"+ob->query_name_cn()+"。\n";
				}
				else if(d_flag==1){
					s += "你阅读了"+ob->query_name_cn()+"。\n";
				}
				me->remove_combine_item(ob->query_name(),1);
			}
		}
	}
	else 
		s += "你没有这件物品\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
