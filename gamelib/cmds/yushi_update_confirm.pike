#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/" 
//���պϳ���ʯ�����õ�ָ��
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
		s += "������������������,������������һ��1��20֮�������\n";
	else if(can_num <= 0)
		s += "�ϳ�ʧ�ܣ���û���㹻�Ĳ���\n";
	else if(num > can_num)
		s += "�ϳ�ʧ�ܣ���û���㹻�Ĳ������ϳ�����ָ����Ŀ��"+yushi_namecn+"\n";
	else{
		//�ۼ���Ҷ�Ӧ����
		string need_yushi = YUSHID->get_yushi_name(rarelevel-1);
		if(me->if_over_easy_load()){
			s += "���������Ʒ���������޷���װ�¸���\n";
		}
		else if(me->query_account()<num*1000){
			s += "�ϳ�ʧ�ܣ������޷�֧���ϳ�����ķ���\n";
			s_log += "�ϳ�ʧ�ܣ����㹻�ķ���";
		}
		else{
			int need_num = me->remove_combine_item(need_yushi,num*10);
			if(need_num == num*10){
				//�۳��ɹ�
				object new_yushi;
				mixed err=catch{
					new_yushi = clone(YUSHI_PATH+yushi_name);
				};
				if(!err && new_yushi){
					string now=ctime(time());
					new_yushi->amount = num;
					me->del_account(num*1000);
					s += "�ϳɳɹ���������"+new_yushi->query_short()+"\n";
					s_log += me->query_name_cn()+"("+me->query_name()+") �� ("+(num*10)+")"+need_yushi+" �ϳ�Ϊ�� ("+num+")"+yushi_name+"\n";
					Stdio.append_file(ROOT+"/log/fee_log/yushi_change-"+MUD_TIMESD->get_year_month()+".log",now[0..sizeof(now)-2]+":"+s_log);
					new_yushi->move_player(me->query_name());
				}
			}
			else
				s += "���Ͽ۳����󣡣�\n";
		}
	}
	s += "\n[����:yushi_myzone.pike]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
