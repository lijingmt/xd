#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name count flag
//ʹ����ս��ʱ���õ�ָ��
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
				s += "�����ս����δʧЧ���Ƿ���Ҫʹ�ã�ʹ�ú󽫸���ԭ����Ч��\n";
				s += "[��:mzf_used "+name+" "+count+" 1] [��:inventory]\n";
			}
			else{
				int eat = BROADCASTD->use_mzhf(me,ob);
				if(eat == 2){
					s += "���Ѿ��ﵽÿ���ʹ�ô������ƣ��޷���ʹ�ô������\n";
				}
				else if(eat == 1){
					string now=ctime(time());
					string s_log = me->query_name_cn()+"("+me->query_name()+") ʹ���� (1)"+ob->query_name_cn()+"\n";
					Stdio.append_file(ROOT+"/log/mianzhan.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
					s += "��ʹ����"+ob->query_name_cn()+"��\n";
					me->remove_combine_item(ob->query_name(),1);
				}
			}
		}
		else if(flag == 1){
			int eat = BROADCASTD->use_mzhf(me,ob);
			if(eat == 2){
				s += "���Ѿ��ﵽÿ���ʹ�ô������ƣ��޷���ʹ�ô������\n";
			}
			else if(eat == 1){
				string now=ctime(time());
				string s_log = me->query_name_cn()+"("+me->query_name()+") ʹ���� ("+ob->amount+")"+ob->query_name_cn()+"\n";
				Stdio.append_file(ROOT+"/log/fee_log/teyao_eat-"+MUD_TIMESD->get_year_month()+".log",now[0..sizeof(now)-2]+":"+s_log+"\n");
				s += "��ʹ����"+ob->query_name_cn()+"��\n";
				me->remove_combine_item(ob->query_name(),1);
			}
		}
	}
	else 
		s += "��û�������Ʒ\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
