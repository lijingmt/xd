#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s="ÿ�οɹ���ر�������λ��10�񣬻���100��\n";
	if(!arg){
		if(me->packageLevel>90)
			s += "���Ѿ��ﵽ�ر���Ŀռ����ޣ��޷��ٽ��й��������ˡ�\n";
		else{
			s += "��ȷ��Ҫ����100����Ĳر���λ��������10��ô��\n";		
			s += "[ȷ������:user_package_buy yes]\n";
			s += "[���ٿ���һ��:user_package_buy no]\n";
		}
	}
	else{
		if(arg=="yes"){
			if(me->packageLevel>90)
				s += "���Ѿ��ﵽ�ر���Ŀռ����ޣ��޷��ٽ��й��������ˡ�\n";
			else{
				if(me->pay_money(10000)==0)
					s += "�����ϵ�Ǯ����֧�����ã��뷵�ء�\n";
				else{
					s += "����ɹ���\n�㻨��"+MUD_MONEYD->query_store_money_cn(10000)+"\n";
					s += "��Ĳر���λ���Ѿ�����10��\n";		
					me->packageLevel = me->packageLevel+10;
					me->command("save");
				}
			}
		}
		else if(arg=="no"){
			s += "�ã�������������ɡ�\n";
		}
	}
	s += "[����:look]\n";
	write(s);
	return 1;
}
