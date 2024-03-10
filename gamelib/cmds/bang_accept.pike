#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = apply_name   flag    index
//      ������id    1��ͨ��  ����������б��е�λ��,Ϊ�����±�+1
//                  0���ܾ�

int main(string arg)
{
	object me = this_player();
	int bangid = me->bangid;
	int rmflag = 0;
	string s = "";
	string content = "";
	string apply_name = "";
	int flag = 0;
	int index;
	sscanf(arg,"%s %d %d",apply_name,flag,index);
	object applyer = find_player(apply_name);
	if(!applyer){
		applyer = me->load_player(apply_name);
		rmflag = 1;
	}
	if(applyer->bangid != 0){
		s += "�Է����а���\n";
		if(BANGD->if_in_apply(applyer,index-1,me->bangid))
			BANGD->rmove_bang_apply(me->bangid,index-1);
	}
	else{
		string bang_name = BANGD->query_bang_name(bangid);
		if(flag){
			if(BANGD->if_in_apply(applyer,index-1,me->bangid)){
				BANGD->rmove_bang_apply(me->bangid,index-1);
				int be = BANGD->add_new_member(apply_name,bangid);
				if(be){
					applyer->bangid=bangid;
					BANGD->bang_notice(bangid,applyer->query_name_cn()+"�����˰���\n");
					s += "��ͨ���˶Է�������\n";
					content = me->query_name_cn()+"ͨ����������룬�������<"+bang_name+">\n";
					applyer->recieve_mail(me->query_name(),me->query_name_cn(),applyer->query_name(),applyer->query_name_cn(),"�������ظ�",content);
					tell_object(applyer,"�����µ��ż����뼴ʱ����\n");
				}
				else
					s += "ͨ������ʧ��\n";
			}
			else
				s += "�������ѱ�����\n";
		}
		else{
			if(BANGD->if_in_apply(applyer,index-1,me->bangid)){
				BANGD->rmove_bang_apply(me->bangid,index-1);
				s += "��ܾ��˶Է�������\n";
				content = me->query_name_cn()+"�ܾ��������<"+bang_name+">�����롣\n";
				applyer->recieve_mail(me->query_name(),me->query_name_cn(),applyer->query_name(),applyer->query_name_cn(),"�������ظ�",content);
				tell_object(applyer,"�����µ��ż����뼴ʱ����\n");
			}
			else
				s += "�������ѱ�����\n";
		}
	}
	if(rmflag)
		applyer->remove();
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "[����:bang_view_apply]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
