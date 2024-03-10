#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	int count=0;
	sscanf(arg,"%s %d",name,count);
	object me = this_player();
	object ob=present(name,me,count);
	object env=environment(me);	
	if(env){
		if(!ob)
			me->write_view(WAP_VIEWD["/emote"],0,0,"������û������������\n");
		else if(!ob->is("item"))
			me->write_view(WAP_VIEWD["/emote"],0,0,"����Ʒ�����ڿ��Խ��׵���Ʒ��\n");
		else if(ob->equiped)
			me->write_view(WAP_VIEWD["/emote"],0,0,"��������װ���Ķ����޷����ۡ�\n");
		else if(!ob->query_item_canTrade())
			me->write_view(WAP_VIEWD["/emote"],0,0,"������Ʒ���ܽ��ס�\n");
		else{
			//�������ϵ���Ʒ�����ߴݻ٣���Ҫ��ʾȷ��
			if(ob->query_item_rareLevel()>=3){
				string stmp = "";
				stmp += "��ȷ��Ҫ���� "+ob->query_name_cn()+"��\n";
				stmp += "[��:sell_confirm "+arg+"]\n";
				stmp += "[��:inventory_sell]\n";
				me->write_view(WAP_VIEWD["/emote"],0,0,stmp);
				return 1;
			}
			int money_num;
			if(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor"||ob->query_item_type()=="decorate"||ob->query_item_type()=="jewelry")
				money_num = (int)ob->query_item_canLevel()*50/4;
			else if(ob->is("combine_item") && ob->query_for_material() != "")
				money_num = ob->value;
			else
				money_num = (int)ob->level_limit*50/4;
			if(money_num<=0) 
				money_num=1;
			//����������Ʒ���ж�//////////////////////////
			if(ob->is_combine_item())
				money_num = money_num*ob->amount;
			//////////////////////////////////////////////
			me->add_money(money_num);
			string msg="���"+ob->name_cn+"�����ˣ���õ���"+MUD_MONEYD->query_store_money_cn(money_num)+"\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,msg);
			ob->remove();
			
			string now=ctime(time());
			string tmp = now[0..sizeof(now)-2]+":"+me->name_cn+"("+me->name+")\n";
			tmp += msg;
			Stdio.append_file(ROOT+"/log/sell.log",tmp+"\n");
		}
	}
	return 1;
}
