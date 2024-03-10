#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name count flag
//使用免战符时调用的指令
int main(string arg)
{
	string s = "";
	object me=this_player();
	string name = "";
	int count = 0;
	int flag = 0;
	string now=ctime(time());
	sscanf(arg,"%s %d %d",name,count,flag);
	object ob=present(name,me,count);
	if(ob && me == environment(ob)){
		string kind = ob->query_danyao_kind();
		if(flag == 0){
			if(me->query_buff(kind,0) != "none"){
				s += "你的免战符还未失效，是否仍要使用？使用后将覆盖原来的效果\n";
				s += "[是:mzf_used "+name+" "+count+" 1] [否:inventory]\n";
			}
			else{
				int eat = BROADCASTD->use_mzhf(me,ob);
				if(eat == 2){
					s += "您已经达到每天的使用次数限制，无法再使用此类灵符\n";
				}
				else if(eat == 1){
					string now=ctime(time());
					string s_log = me->query_name_cn()+"("+me->query_name()+") 使用了 (1)"+ob->query_name_cn()+"\n";
					Stdio.append_file(ROOT+"/log/mianzhan.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
					s += "你使用了"+ob->query_name_cn()+"。\n";
					me->remove_combine_item(ob->query_name(),1);
				}
			}
		}
		else if(flag == 1){
			int eat = BROADCASTD->use_mzhf(me,ob);
			if(eat == 2){
				s += "您已经达到每天的使用次数限制，无法再使用此类灵符\n";
			}
			else if(eat == 1){
				string now=ctime(time());
				string s_log = me->query_name_cn()+"("+me->query_name()+") 使用了 ("+ob->amount+")"+ob->query_name_cn()+"\n";
				Stdio.append_file(ROOT+"/log/fee_log/teyao_eat-"+MUD_TIMESD->get_year_month()+".log",now[0..sizeof(now)-2]+":"+s_log+"\n");
				s += "你使用了"+ob->query_name_cn()+"。\n";
				me->remove_combine_item(ob->query_name(),1);
			}
		}
	}
	else 
		s += "你没有这件物品\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
