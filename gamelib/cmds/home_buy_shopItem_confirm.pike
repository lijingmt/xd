#include <command.h>
//#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	object env = environment(me);
	string s = "";
	string masterId = "";
	string itemName = "";
	string s_log = "";
	int price = 0;
	int priceFlag = 0;//1����ʯ 0���ƽ�
	int shopId = 0;
	int tradeResult = 0;
	int timeDelay = 0;
	string moneyPath = "";
	sscanf(arg,"%s %d %d %d %d",masterId,price,priceFlag,shopId,timeDelay);
	if(priceFlag==1){
		tradeResult = BUYD->do_trade(me,price,0,1);
		moneyPath = "yushi/suiyu";
	}
	else{
		tradeResult = BUYD->do_trade(me,0,price,1);
		moneyPath = "money";
	}
	switch(tradeResult){
		case 0:
			s += "�����ϵ���ʯ������\n";
			break;
		case 1:
			s += "�����ϵĽ�Ǯ������\n";
			break;
		case 2:
			s += "���ı���������������װ�������Ķ���\n";
			break;
		case 3:
			object item;
			item = HOMED->get_shop_item(masterId,shopId);
			if(item){
				s += "���ɹ�������"+item->query_name_cn()+"\n";
				HOMED->change_flag(masterId,shopId,2);//�ı��־λ
				if(item->is("combine_itme"))
					me->move_player(me->query_name());
				else
					item->move(me);
			}
			//��¼�����Ľ��׽�������������
			price = (int)(price * (100-HOMED->get_tax(timeDelay))/100);
			object master;
			int remove_flag = 0;
			master = find_player(masterId);
			if(!master){
				me->load_player(masterId);
				remove_flag = 1;
			}
			if(master){
				master->set_home_sale(priceFlag,price);
				if(remove_flag)
					master->remove();
			}
			break;
		default:
			s += "ϵͳ�����ˣ���͹���Ա��ϵ��\n";
			break;
	}
	s += "\n\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
