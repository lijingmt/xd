#include <command.h>
#include <gamelib/include/gamelib.h>
//��ָ������һ�ý�����Ʒ
//arg = gift_name num
//      ��Ʒ�ļ�����ǮΪmoney�� ����
int main(string arg)
{
	string s = "";
	string gift_name = "";
	string now=ctime(time());
	string s_log = "";
	int num = 0;
	sscanf(arg,"%s %d",gift_name,num);
	object me=this_player();
	int can = GIFTD->if_can_take(me->query_name(),gift_name);
	if(can == 1){
		if(gift_name == "money"){
			me->account += num;
			GIFTD->flush_gift_m(me->query_name(),gift_name,num);
			s += "��ȡ�ɹ���\n��õ���"+MUD_MONEYD->query_other_money_cn(num)+"\n";
			s_log += me->query_name_cn()+"("+me->query_name()+") ��ȡ��"+MUD_MONEYD->query_other_money_cn(num)+"\n";
		}
		else{
			object gift_ob;
			mixed err=catch{
				gift_ob = clone(ITEM_PATH+gift_name);
			};
			if(err || !gift_ob){
				s += "��ȡʧ��\n����ϵ��Ϸ���������ǽ����������\n";
			}
			else{
				s += "��ȡ�ɹ���\n������ "+gift_ob->query_name_cn()+"\n";
				s_log += me->query_name_cn()+"("+me->query_name()+") ��ȡ�� "+gift_ob->query_name_cn()+"\n";
				if(gift_ob->is("combine_item"))
					gift_ob->move_player(me->query_name());
				else
					gift_ob->move(me);
				GIFTD->flush_gift_m(me->query_name(),gift_name,num);
			}
		}
	}
	else
		s += "�޷���ȡ\n���Ѿ���ȡ��������Ʒ���Ǯ��\n";
	if(s_log != "")
		Stdio.append_file(ROOT+"/log/get_gift.log",now[0..sizeof(now)-2]+":"+s_log);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[����:gift_info_view]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
