#include <command.h>
#include <gamelib/include/gamelib.h>  
//��ָ�������˳���ս
//arg : flag=0 �鿴  =1 �������
int main(string arg)
{
	string s = "";
	object me=this_player();
	int flag = (int)arg;
	int fee = 1000000;//���ɵķ���
	if(me->bangid == 0)
		s += "����δ�����κΰ���\n";
	else if(me->query_name() != BANGD->query_root_name(me->bangid))
		s += "�����ǰ�������Ȩ�����˳�\n";
	else{
		if(flag == 0){
			s += "�˳���ս����״��\n";
			s += "����״�ɲ�����Ӿͼӣ����˾��˵ġ�\n";
			s += "���������10000������˳�����״��\n";
			s += "ע�⣺һ���˳�������״�������ɵİ�����������������ʧ��\n";
			s += "[ȷ���˳�:bz_quit 1] [ȡ��:bz_get_info]\n";
		}
		else if(flag == 1){
			if(me->query_account()<fee){
				s += "�����ϵ�Ǯ����\n";
			}
			else{
				int quit_fg = BANGZHAND->quit_bangzhan(me->bangid);
				if(quit_fg == 1){
					me->del_account(fee);
					s += "���İ����Ѿ��ɹ��˳���ս����״��\n";
				}
				else if(quit_fg == 2) 
					s += "�˳�ʧ�ܣ����İ��ɲ�δ������״�С�\n";
				else 
					s += "�˳�ʧ�ܣ����İ��������⣡\n";
			}
		}
		//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	}
	s += "\n[������Ϸ:look]\n";
	write(s);
	return 1;
}
