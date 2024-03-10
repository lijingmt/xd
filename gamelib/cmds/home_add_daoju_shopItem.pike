#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	//string s="��Ҫ����ʲô��Ʒ��\n";
	object me = this_player();
	int shopId = (int)arg;
	string list = "home_shop";
	//this_player()->write_view(WAP_VIEWD["/home_add_daoju_shopItem"]);
	mapping(string:int) name_count=([]);
	array(object) items=all_inventory(me);
	string out="��ѡ����Ҫ���۵���Ʒ\n";
	string out_no_equip="";
	int count_max = me->query_beibao_size();//�û�������ʵ�����������������ģ�
	if(items&&sizeof(items)){
		out+="(��Ʒ��"+sizeof(items)+"/"+count_max+")\n";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())&&items[i]->query_item_type()!="yushi"){
				//����-װ����Ʒ��������
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry")
				inv_count++;
				//����-��ʳ����Ʒ
				else if(items[i]->query_item_type()=="food"||items[i]->query_item_type()=="water"){
					out_no_equip+="["+items[i]->query_short();
					out_no_equip+="("+MUD_MONEYD->query_store_money_cn((items[i]->level_limit*50/4)*items[i]->amount)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//��Ϊ���죬����ԭ���ϵ���Ʒ����,�۸�=value*amount
				else if(items[i]->is("combine_item") && items[i]->query_for_material() != ""){
					out_no_equip+="["+items[i]->query_short();
					out_no_equip+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_value()*items[i]->amount)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//����-һ����Ʒ��������Ʒ��������Ʒ��,�޼۸���ʾ
				else{
					//���������ģ�������ʾ,���������ģ����ݲ߻�����۸�ؼ������������õ��۸�
					if(!items[i]->query_item_task()){
						out_no_equip+="["+items[i]->query_short();
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
						name_count[items[i]->query_name()]++;
						daoju_count++;
					}
				}
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(list=="home_shop"){
			if(inv_count)
				howitem += "[װ��("+inv_count+"):home_add_shopItem "+arg+"]";
			else
				howitem += "װ��("+inv_count+")";
			if(daoju_count)
				howdaoju += "[����("+daoju_count+"):home_add_daoju_shopItem "+arg+"]";
			else
				howdaoju += "����("+daoju_count+")";
		}
			out += howitem + " " + howdaoju+"\n";	
	}
	if(out_no_equip==""){
		out += "������û�п��Գ��۵ĵ���\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,out+out_no_equip);
	return 1;
}
