#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = flag 
//��ָ��������۽���Ʒʱ���ȵ��ã��г��������ui
int main(string arg)
{
	string s = "";
	object me=this_player();
	string item_name = "";
	int flag = (int)arg;
	int count = 0;
	int have_i = 0;
	int have_ganlanshi = 0;
	int have_lvsongshi = 0;
	int have_jianjingshi = 0;
	int have_qingjinshi =0;
	if(me->vice_skills["duanzao"] == 0)
		s += "�����ڲ�������켼��\n";
	else{
		array(object) all_obj = all_inventory(me);
		if(flag == 0)
			me->ronglian_list = ([]);
		foreach(all_obj,object ob){
			if(ob && ob->query_name()=="ganlanshi"){
				have_ganlanshi += ob->amount;
			}
			if(ob && ob->query_name()=="lvsongshi"){
				have_lvsongshi+= ob->amount;
			}
			if(ob && ob->query_name()=="jianjingshi"){
				have_jianjingshi += ob->amount;
			}
			if(ob && ob->query_name()=="qingjinshi"){
				have_qingjinshi += ob->amount;
			}
		}
		s += "��������װ����\n";
		s += "[������������Ʒһ:viceskill_ronglian_item weapon 1]\n";
		if(me->ronglian_list[1] != 0){
			array tmp1 = me->ronglian_list[1];
			item_name = tmp1[0];
			count = tmp1[1];
			object r1 = present(item_name,me,count);
			if(r1){
				s += r1->query_name_cn()+"\n";
			}
			else
				s += "���װ�������⡣\n";
		}
		else 
			s += "��\n";
		s += "[������������Ʒ��:viceskill_ronglian_item weapon 2]\n";
		if(me->ronglian_list[2] != 0){
			array tmp2 = me->ronglian_list[2];
			item_name = tmp2[0];
			count = tmp2[1];
			object r2 = present(item_name,me,count);
			if(r2){
				s += r2->query_name_cn()+"\n";
			}
			else
				s += "���װ�������⡣\n";
		}
		else 
			s += "��\n";
		s += "[����:viceskill_ronglian_confirm]\n";
		s += "[���ʯ��������:viceskill_ronglian_confirm 1](x"+have_ganlanshi+")\n";
		s += "[����ʯ��������:viceskill_ronglian_confirm 2](x"+have_lvsongshi+")\n";
		s += "[�⾧ʯ��������:viceskill_ronglian_confirm 3](x"+have_jianjingshi+")\n";
		s += "[���ʯ��������:viceskill_ronglian_confirm 4](x"+have_qingjinshi+")\n";
		s += "[�鿴����������:viceskill_ronglian_spec]\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "\n[������Ϸ:look]\n";
	//write(s);
	return 1;
}
