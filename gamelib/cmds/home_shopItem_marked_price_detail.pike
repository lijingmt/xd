#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string name ="";
	int timeDelay = 0;
	string s_xy = "";
	string s_sy = "";
	string s_hj = "";
	string s_by = "";
	int xianyu = 0;
	int suiyu = 0;
	int jin = 0;
	int yin = 0;
	int price = 0;
	int ind = 0; //̯λ
	int count = -1;//���۵���������԰���Ʒ
	int all_amount = 0;
	string s_count = "";
	object env=environment(me);
	object ob ;
	string s = "";
//	werror("-----arg="+arg+"--\n");
	if(sscanf(arg,"%s %d %d %s %s %s %s %s",name,ind,timeDelay,s_count,s_hj,s_by,s_sy,s_xy)==8){
//	werror("-----s_count="+s_count+"---s_hj="+s_hj+"s_by="+s_by+"s_sy="+s_sy+"s_xy="+s_xy+"--\n");
		sscanf(s_count,"nu=%d",count);
		sscanf(s_xy,"xy=%d",xianyu);
		sscanf(s_sy,"sy=%d",suiyu);
		sscanf(s_hj,"hj=%d",jin);
		sscanf(s_by,"by=%d",yin);
	}
	else{
		sscanf(arg,"%s %d %d %s %s %s %s",name,ind,timeDelay,s_hj,s_by,s_sy,s_xy);
		sscanf(s_xy,"xy=%d",xianyu);
		sscanf(s_sy,"sy=%d",suiyu);
		sscanf(s_hj,"hj=%d",jin);
		sscanf(s_by,"by=%d",yin);
	}
	array(object) all_ob = all_inventory(me);
	foreach(all_ob,object each_ob){
		if(each_ob->query_name()==name&&(!each_ob->query_toVip())){
			if(each_ob->is("combine_item")){
				all_amount += each_ob->amount;
				ob = each_ob;
			}
			else{
				ob = each_ob;
				count = 1;
				break;
			}
		}
	}
	if(env && ob){
		if(ob->is("combine_item")){
			//�ж��Ƿ��㹻
			if(count>20||count<1){
				s += "��������������󣬳�������������1��20֮��\n";
				s += "[��������:home_shopItem_marked_price "+name+" "+ind+" "+timeDelay+"]\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			else if(count>all_amount){
				s += "�����������������ӵ�е�"+ob->query_name_cn()+"������,����ȷ����\n";
				s += "[��������:home_shopItem_marked_price "+name+" "+ind+" "+timeDelay+"]\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
		}
		//�������,���Ա��
		if(xianyu!=0||suiyu!=0){
			if(jin!=0||yin!=0){
				s += "�۸�ֻ��Ϊ��������ȷ����\n";
				s += "[���±��:home_shopItem_marked_price "+name+" "+ind+" "+timeDelay+"]\n";
			}
			else{
				price = xianyu*10+suiyu;
				s += "������"+YUSHID->get_yushi_for_desc(price)+"����"+ob->query_name_cn()+"����Ϊ"+timeDelay+"�죬���׳ɹ�������"+HOMED->get_tax(timeDelay)+"%����˰\n";
				//s += "������"+YUSHID->get_yushi_for_desc(price)+"����"+count+ ob->unit +ob->query_name_cn()+"����Ϊ"+timeDelay+"�죬���׳ɹ�������"+HOMED->get_tax(timeDelay)+"%����˰\n";
				s += "��ȷ��������\n";
				s += "[ȷ��:home_shopItem_marked_price_confirm 1 "+name+" "+count+" "+timeDelay+" "+price+" "+ind+"]\n";
				s += "[��������:home_myzone]\n";
			}
		}
		else{
			if(jin==0&&yin==0){
				s += "���Ѹ���Ʒ�ļ۸�����Ϊ0��������൱��������Ͱ�~��ȷ��Ҫ��ô����\n";
				s += "[ȷ��:home_shopItem_marked_price_confirm 0 "+name+" "+count+" "+timeDelay+" "+price+" "+ind+"]\n";
				s += "[���±��:home_shopItem_marked_price "+name+" "+ind+" "+timeDelay+"]\n";
			}
			else{
				price = jin*100+yin;
				s += "������"+jin+"��"+yin+"������"+count+ ob->unit +ob->query_name_cn()+"����Ϊ"+timeDelay+"�죬���׳ɹ�������"+HOMED->get_tax(timeDelay)+"%����˰\n";
				s += "��ȷ��������\n";
				s += "[ȷ��:home_shopItem_marked_price_confirm 0 "+name+" "+count+" "+timeDelay+" "+price+" "+ind+"]\n";
				s += "[��������:home_myzone]\n";
			}
		}

	}
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
