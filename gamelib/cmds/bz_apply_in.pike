#include <command.h>
#include <gamelib/include/gamelib.h>  
//��ָ����������ս
//arg : flag=0 �鿴  =1 �������
int main(string arg)
{
	string s = "";
	object me=this_player();
	int flag = (int)arg;
	int fee = 500000;//���ɵķ���
	if(me->bangid == 0)
		s += "����δ�����κΰ���\n";
	else if(me->query_name() != BANGD->query_root_name(me->bangid))
		s += "�����ǰ�������Ȩ�������\n";
	else{
		if(flag == 0){
			s += "�����ս����״��\n";
			s += "��������5000������Ѽ�������״��\n";
			s += "[ȷ��:bz_apply_in 1] [ȡ��:bz_get_info]\n";
		}
		else if(flag == 1){
			if(me->query_account()<fee){
				s += "�����ϵ�Ǯ����\n";
			}
			else{
				int add_fg = BANGZHAND->add_new_bang(me->bangid);
				if(add_fg == 1){
					me->del_account(fee);
					s += "���İ����Ѿ��ɹ������ս����״��\n";
				}
				else if(add_fg == 2) 
					s += "����ʧ�ܣ����İ����Ѿ�������ˡ�\n";
				else 
					s += "����ʧ�ܣ����İ��������⣡\n";
			}
		}
		//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	}
	s += "\n[������Ϸ:look]\n";
	write(s);
	return 1;
}
