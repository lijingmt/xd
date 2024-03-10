#include <command.h>
#include <gamelib/include/gamelib.h>

#define PATH ROOT "/gamelib/clone/item/bossdrop/"

/*******************************************************************************
 *��ָ���û���ǩ�̶���ȡ��Ʒģ��
 *argΪ�գ��г�����ǩ�ɻ�ȡ����Ʒ�嵥
 *arg = item_name,exchange_count
 *exchange_count ����Ļ�ȡ��Ʒ������
 *********************************************************************************/

int main(string arg){
	object me = this_player();
	object item;
	string item_name = "";
	string s = "";
	string s_log = ""; 
	//int count = 0;
	int exchange_count = 0;
	int have_huoyueqian = 0;
	array(object) all_ob =all_inventory(me);
	foreach(all_ob,object ob){
		if(ob->is_combine_item()&&ob->query_name()=="huoyueqian"){
			have_huoyueqian += ob->amount;
		}
	}
	if(!have_huoyueqian){
		s += "����ǩ���Ի�ȡ�����ռǡ�Ѫ��ʯ���߻�����Ƭ��\n";
		s += "���������ڲ�û�л���ǩ��\n";
		s += "��ȥ��û���ǩ�ٹ�����:��\n";
		s += "����ǩ����ͨ��������50Ԫ�������\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(!arg){
		s += "����ǩ�ɻ�ȡ����Ʒ�б�:\n";
		s += "--------\n";
		s += "[�����ռ�:hyq_exchange bawanghuiji 0](x"+have_huoyueqian+")\n";
		s += "[Ѫ��ʯ:hyq_exchange xuehuoshi 0](x"+have_huoyueqian+")\n";
		s += "[������Ƭ:hyq_exchange hundunsuipian 0](x"+have_huoyueqian+")\n";
		s += "\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(arg){
		sscanf(arg,"%s %d",item_name,exchange_count);
		//werror("------name------------"+item_name+"-----------\n");
		//werror("------name1------------"+exchange_count+"-----------\n");
		//sscanf(exchange_count,"no=%d",count);
		if(!item_name){
			s += "�ⶫ�������е㲻��ͷ��\n";
			s += "[������ȡ:hyq_exchange]\n";
			s += "[������Ϸ:look]\n";
			write(s);
			return 1;
		}
		if(!exchange_count){
			object item_ob = (object)(PATH+item_name);
			string item_name_cn = item_ob->query_name_cn();
			s += "��ȡ"+item_name_cn+"��Ҫһ֧����ǩ��\n";
			s += item_describe(item_name);
			s += "��Ŀǰ����"+have_huoyueqian+"֧����ǩ�ɻ�ȡ\n";
			s += "��������Ҫ��ȡ������(1-20):\n";
			//s += "[int no:...]\n";
			s += "[��ȡ:hyq_exchange "+item_name+" ...]\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		else{
			object item_ob = (object)(PATH+item_name);
			string item_name_cn = item_ob->query_name_cn();
			if(exchange_count>20||exchange_count<0){
				s += "���������������ȷ����ȡ�����������0С�ڵ���20\n";
				s += "[������ȡ:hyq_exchange]\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			if(exchange_count>have_huoyueqian){
				s += "��û���㹻�Ļ���ǩ�������ɻ�"+have_huoyueqian+item_name_cn+"\n";
				s += "[������ȡ:hyq_exchange]\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			//��������
			mixed err = catch{
				item = clone(PATH+item_name);
			};
			if(!err&&item){
				if(me->if_over_load(item)){
					s += "��������Ʒ�������޷���Ÿ���Ķ�����\n";
				}
				else{
					item->amount = exchange_count;
					item->move(me);
					me->remove_combine_item("huoyueqian",exchange_count);
					s += "��ȡ�ɹ����������"+exchange_count+item_name_cn+"��\n";
					s_log += me->query_name_cn()+"("+me->query_name()+")"+"����"+exchange_count+"֧����ǩ��ȡ"+exchange_count+item_name_cn+"\n";
					string now=ctime(time());
					Stdio.append_file(ROOT+"/log/hyq_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
				}
			}
		}
	}
	s += "[����:hyq_exchange]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}


string item_describe(string item_name){
	string s = "";
	if(item_name=="bawanghuiji"){
		s += "ƾ�����Ʒ���Ի�������������������Ʒ��\n";
	}
	else if(item_name=="xuehuoshi"){
		s += "����Ʒ�ɻ�ȡ55���»þ�������������\n";
	}
	else if(item_name=="hundunsuipian"){
		s += "����Ʒ�ɻ�ȡ55���»þ������硿��Ʒ��\n";
	}
	return s;
}
