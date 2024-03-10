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
			me->write_view(WAP_VIEWD["/emote"],0,0,"你身上没有那样东西。\n");
		else if(!ob->is("item"))
			me->write_view(WAP_VIEWD["/emote"],0,0,"该物品不属于可以交易的物品。\n");
		else if(ob->equiped)
			me->write_view(WAP_VIEWD["/emote"],0,0,"身上正在装备的东西无法出售。\n");
		else if(!ob->query_item_canTrade())
			me->write_view(WAP_VIEWD["/emote"],0,0,"该类物品不能交易。\n");
		else{
			//精致以上的物品卖或者摧毁，需要提示确定
			if(ob->query_item_rareLevel()>=3){
				string stmp = "";
				stmp += "你确定要卖掉 "+ob->query_name_cn()+"吗？\n";
				stmp += "[是:sell_confirm "+arg+"]\n";
				stmp += "[否:inventory_sell]\n";
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
			//单，复数物品的判定//////////////////////////
			if(ob->is_combine_item())
				money_num = money_num*ob->amount;
			//////////////////////////////////////////////
			me->add_money(money_num);
			string msg="你把"+ob->name_cn+"卖掉了，你得到了"+MUD_MONEYD->query_store_money_cn(money_num)+"\n";
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
