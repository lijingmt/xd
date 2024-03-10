#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string name ="";
	int count = 0;
	int timeDelay = 0;
	int shopId = 0;
	object env=environment(me);
	string s = "";
	object ob;
	sscanf(arg,"%s %d %d",name,shopId,timeDelay);
	array(object) all_ob = all_inventory(me);
	foreach(all_ob,object each_ob){
		if(each_ob->query_name()==name&&(!each_ob->query_toVip())){
			ob = each_ob;
			break;
		}
	}
	if(env){
		if(!ob)
			me->write_view(WAP_VIEWD["/emote"],0,0,"������û������������\n");
		else if(!ob->is("item"))
			me->write_view(WAP_VIEWD["/emote"],0,0,"����Ʒ�����ڿ��Գ��۵���Ʒ��\n");
		else if(ob->equiped)
			me->write_view(WAP_VIEWD["/emote"],0,0,"��������װ���Ķ����޷����ۡ�\n");
		else if(ob->query_item_save() == 0)
			me->write_view(WAP_VIEWD["/emote"],0,0,"����Ʒ���ܳ��ۡ�\n");
		else if(!ob->query_item_canTrade())
			me->write_view(WAP_VIEWD["/emote"],0,0,"������Ʒ���ܳ��ۡ�\n");
		else if(ob->query_toVip())
			me->write_view(WAP_VIEWD["/emote"],0,0,"��Աר����Ʒ���ܳ��ۡ�\n");
		else if((ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor")&&ob->item_cur_dura<ob->item_dura)
			me->write_view(WAP_VIEWD["/emote"],0,0,"���������ⲻ�ܳ��ۣ�����ȥ���������İ�\n");
		else{
			s += "Ϊ��Ҫ���۵���Ʒ�����ۣ�\n";
			s += ob->query_name_cn()+"\n";
			int price = 0;
			if(ob->is("combine_item")){
				if(ob->query_item_type()=="food"||ob->query_item_type()=="water"||ob->query_item_type()==""){
					price = (ob->level_limit*50/4)*ob->amount;
				}
				else if(ob->query_for_material() != ""){
					price = ob->query_value()*ob->amount;
				}
			}
			else if(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor"||ob->query_item_type()=="decorate"||ob->query_item_type()=="jewelry"){
				price = ob->query_item_canLevel()*50/4;
			}
			if(price)
				s += "(�г��ۣ�"+MUD_MONEYD->query_store_money_cn(price)+")\n";
			if(ob->is("combine_item")){
				s += "��������Ҫ���۵�������\n";
				s += "[int nu:...]\n";
			}
			s += "����������Ҫ���۵ļ۸�\n";
			s += "[int xy:...]��Ե��[int sy:...]����\n";
			s += "��\n";
			s += "[int hj:...]��[int by:...]��\n";
			s += "[submit ȷ��:home_shopItem_marked_price_detail "+name+" "+shopId+" "+timeDelay+" ...]";
			s += "\n\n";
			s += "[��������:home_shop_service_center "+env->query_masterId()+"]\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
		}
	}
	return 1;
}
