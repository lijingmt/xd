#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	s +="[1����ˢ��:list_spec 1 1][1����ˢ��:list_spec 2 1000000]\n";
	int count = 0;
	int rarelevel = 1;//������1��Խ��Խ��
	int need_amount = 1;//��Ҫ����
	object me = this_player();
	if(arg){
		sscanf(arg,"%d %d",count, need_amount);
		if(count == 2){
			int fee = need_amount;
			if(me->pay_money(fee)==0){
				s+="���Ľ�Ҳ���"+MUD_MONEYD->query_store_money_cn(fee)+"���뷵�ء�\n";
			}else{
				//s +=MUD_MONEYD->query_store_money_cn(fee)+"����ɹ�\n";
				s += environment(this_player())->view_goods_spec_list();
			}
		}else if(count == 1){
			string need_yushi = YUSHID->get_yushi_name(rarelevel);
			string need_yushicn = YUSHID->get_yushi_namecn(rarelevel);
			//���������ϴ�����ʯ�ĸ���
			int have_num = YUSHID->query_yushi_num(me,rarelevel);
				//���㵽����ܹ�����˴�������������
			int can_num = have_num/need_amount;
			//ÿ����һ�����Ϳ۳�һ�������ĵ���ʯ��
			if(can_num){
				me->remove_combine_item(need_yushi,need_amount);
				//s += "���׳ɹ�����������̵��������\n";
				s += environment(this_player())->view_goods_spec_list();
			}else{
				s +="����"+need_yushicn+"��������ˢ��ʧ�ܣ� ����ϵ�ͷ�������ȡ\n";
			}
		}
		
	}
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);

	return 1;
	
}
