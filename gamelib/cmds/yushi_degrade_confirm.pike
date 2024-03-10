#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/" 
//���պϳ���ʯ�����õ�ָ��
//arg =         yushi_name            rarelevel                      num
//        �����õ�����ʯ�ļ���   �õ�����ʯ��ϡ�ж�      ���ָ���ı�������ʯ�ĸ���
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
		s += "������������������,������������1��5֮�������\n";
	else if(can_num <= 0)
		s += "����ʧ�ܣ���û���㹻��"+need_namecn+"\n";
	else if(num > can_num)
		s += "����ʧ�ܣ���û������ָ����Ŀ��"+need_namecn+"\n";
	else{
		//�ۼ���Ҷ�Ӧ����
		string need_yushi = YUSHID->get_yushi_name(rarelevel+1);
		//int need_num = me->remove_combine_item(need_yushi,num);
		if(num){
		//�۳��ɹ�
			s_log += me->query_name_cn()+"("+me->query_name()+") �������("+num+")"+need_yushi+",���Ϊ:";
			object new_yushi;
			int i = num*10/30;//�õ�����������
			int j = (num*10)%30;//�õ�����һ��ĸ���
			mixed err;
			for(int k=1;k<=i;k++){
				err=catch{
					new_yushi = clone(YUSHI_PATH+yushi_name);
				};
				if(!err && new_yushi){
					if(me->if_over_easy_load()){
						s += "����ʧ�ܣ����������Ʒ����\n";
						s_log += "����ʧ�ܣ�������Ʒ����";
						break;
					}
					else if(me->query_account()<3000){
						s += "����ʧ�ܣ������޷�֧���������\n";
						s_log += "����ʧ�ܣ����㹻�ķ���";
						break;
					}
					else{
						new_yushi->amount = 30;
						me->del_account(3000);
						me->remove_combine_item(need_yushi,3);
						s += "����ɹ���������"+new_yushi->query_short()+"\n";
						s_log += " ��(3)"+need_yushi+"������(30)"+yushi_name+",";
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
						s += "����ʧ�ܣ����������Ʒ����\n";
						s_log += "����ʧ�ܣ�������Ʒ����";
					}
					else if(me->query_account()<money){
						s += "����ʧ�ܣ������޷�֧���������\n";
						s_log += "����ʧ�ܣ�������Ʒ����";
					}
					else{
						me->del_account(money);
						me->remove_combine_item(need_yushi,1);
						s += "����ɹ���������"+new_yushi->query_short()+"\n";
						if(j>10)
							s_log += " ��(2)"+need_yushi+"������("+j+")"+yushi_name+",";
						else
							s_log += " ��(1)"+need_yushi+"������("+j+")"+yushi_name+",";
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
			s += "���Ͽ۳����󣡣�\n";
	}
	s += "\n[����:yushi_myzone.pike]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
