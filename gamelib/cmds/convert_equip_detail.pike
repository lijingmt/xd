#include <command.h>
#include <gamelib/include/gamelib.h>
//��ָ���г���������ָ������Ҫת����ĳ��װ������Ϣ
//arg = item_name 
//      cost    ��flag==1��==2ʱ��Ҫ����ʯ����
//      flag    0 --��һ�ν����ҳ��  1--ת���ɹ�  2--���ӳɹ� 3--����ʧ��  4--����ɹ�                 
int main(string arg)
{
	string s = "";
	string item_name = "";//�����Ҫת������Ʒ�ļ���
	object me=this_player();
	object item;//�����Ҫת������Ʒobject
	int can_convert = 0;
	int flag = 0;
	int rareLevel = 0;//��Ʒ��ϡ�еȼ�
	int canLevel = 0;//��Ʒ�Ĵ����ȼ�
	int convert_cost = 0;//����ת����Ҫ����ʯ��
	int add_cost = 0;//����������Ҫ����ʯ��
	sscanf(arg,"%s %d",item_name,flag);
	array(object) all_obj = all_inventory(me);
	foreach(all_obj,object ob){
		//if(ob && ob->query_item_rareLevel()>0 && !ob["equiped"]){
		if(ob && ITEMSD->can_equip(ob) &&((ob->query_item_rareLevel()>0)||(ob->query_item_canLevel()>=1&&(sizeof(ob->query_name_cn()/"��"))==1))){
			if(ob->query_name() == item_name){
				can_convert = 1;
				item = ob;
				break;
			}
		}
	}
	if(can_convert && item){
		if(flag == 1){
			s += "ת���ɹ���(^0^)\n";
			//if(me->query_vip_flag())
			//	s += "�������ǻ�Ա�����β�����ȫ��ѣ�\n";
		}
		else if(flag == 2)
			s += "���ӳɹ���(^0^)\n";
		else if(flag == 3)
			s += "����ʧ�ܣ�(T_T)\n";
		else if(flag == 4)
			s += "����ɹ���(^0^)\n";
		rareLevel = item->query_item_rareLevel();
		canLevel = item->query_item_canLevel();
		//ȷ��ת����Ҫ����ʯ��
		switch(canLevel){
			case 1..10:
				convert_cost = 2;
				break;
			case 11..20:
				convert_cost = 4;
				break;
			case 21..30:
				convert_cost = 6;
				break;
			case 31..40:
				convert_cost = 8;
				break;
			case 41..49:
				convert_cost = 10;
				break;
			default:
				convert_cost = 10;
		}
		//�õ�����������Ҫ���ĵ���ʯ��
		add_cost = convert_cost;
		/*
		   switch(canLevel){
		   case 1..9:
		   add_cost = canLevel;
		   break;
		   case 10..18:
		   add_cost = 10;
		   break;
		   case 19..28:
		   add_cost = 20;
		   break;
		   case 29..38:
		   add_cost = 30;
		   break;
		   case 39..48:
		   add_cost = 40;
		   break;
		   case 49:
		   add_cost = 50;
		   break;
		   default:
		   add_cost = 50;
		   }
		 */
		//�����Ҫ�Ľ�Ǯ��
		string s_money = MUD_MONEYD->query_other_money_cn(canLevel*100);
		s += item->query_name_cn()+"\n";
		s += item->query_picture_url()+"\n"+item->query_desc()+"\n";
		s += item->query_content()+"\n";
		int have_binglanyushi = 0;
		int have_zijinyushi = 0;
		int have_huposhi = 0;
		int have_cuijinshi = 0;
		array(object) all_obj = all_inventory(me);
		foreach(all_obj,object ob){
			if(ob && ob->query_name()=="binglanyushi"){
				have_binglanyushi += ob->amount;
			}
			if(ob && ob->query_name()=="zijinyushi"){
				have_zijinyushi += ob->amount;
			}
			if(ob && ob->query_name()=="huposhi"){
				have_huposhi += ob->amount;
			}
			if(ob && ob->query_name()=="cuijinshi"){
				have_cuijinshi += ob->amount;
			}
		}
		if(item->query_item_rareLevel()!=0){
			s += "ת����Ҫ��"+YUSHID->get_yushi_for_desc(convert_cost)+","+s_money+"\n";
			s += "[ת������:convert_equip_confirm "+item->query_name()+" "+item->query_item_type()+" "+convert_cost+" 1 0]\n";
			s += "[��Ա���ת��:convert_equip_confirm "+item->query_name()+" "+item->query_item_type()+" 0 1 1]\n";
			s += "[ת����������:convert_equip_reset "+item->query_name()+"](x"+have_zijinyushi+")\n";}
			s += "������Ҫ��"+YUSHID->get_yushi_for_desc(add_cost)+","+s_money+"\n";
			s += "[��������:convert_equip_confirm "+item->query_name()+" "+item->query_item_type()+" "+add_cost+" 2 0]\n";
			s += "[��Ա�Ż���������:convert_equip_vip_off "+item->query_name()+" "+item->query_item_type()+" "+add_cost+" 2]\n";
			s += "[������ʯ��������:convert_equip_confirm "+item->query_name()+" "+item->query_item_type()+" "+add_cost+" 3](x"+have_binglanyushi+")\n";
			if(item->query_item_rareLevel()==0){
				s += "[����ʯ��������:convert_equip_confirm "+item->query_name()+" "+item->query_item_type()+" "+add_cost+" 4](x"+have_huposhi+")\n";
			}
			if(item->query_item_rareLevel()==1||item->query_item_rareLevel()==2){
				s += "[�侧ʯ��������:convert_equip_confirm "+item->query_name()+" "+item->query_item_type()+" "+add_cost+" 5](x"+have_cuijinshi+")\n";
			}
	}
	else 
		s += "��Ҫ������װ���������ڣ��뷵��\n";
	s += "[����:convert_equip_list]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
	}
