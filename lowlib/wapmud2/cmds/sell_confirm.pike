#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name,cfm=arg;
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
			//精致以上的物品卖，经过了提示确定
			int money_num;
			if(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor"||ob->query_item_type()=="decorate"||ob->query_item_type()=="jewelry")
				money_num = (int)ob->query_item_canLevel()*50/4;
			else
				money_num = (int)ob->level_limit*50/4;
			if(money_num<=0) 
				money_num=1;
			me->add_money(money_num);
			string msg="你把"+ob->name_cn+"卖掉了，你得到了"+MUD_MONEYD->query_store_money_cn(money_num)+"\n";
			msg += "[返回:inventory_sell]\n";
			msg += "[返回游戏:look]\n";
			write(msg);
			//me->write_view(WAP_VIEWD["/emote"],0,0,msg);
			ob->remove();

			string now=ctime(time());
			string tmp = now[0..sizeof(now)-2]+":"+me->name_cn+"("+me->name+")\n";
			tmp += msg;
			Stdio.append_file(ROOT+"/log/sell.log",tmp+"\n");
		}
	}
	return 1;
}
