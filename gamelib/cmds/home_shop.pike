#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string name ="";
	int count = 0;
	object env=environment(me);
	string s = "";
	int ind ;//̯λid
	object ob;
	sscanf(arg,"%s %d %d",name,count,ind);
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
			s += "��ѡ����Ҫ���۵����ޣ�\n";
			s += HOMED->get_time_delay_list(name,ind,"home_shopItem_marked_price");
			s += "\n\n";
			s += "[��������:home_shop_service_center "+env->query_masterId()+"]\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
		}
	}
	return 1;
}
