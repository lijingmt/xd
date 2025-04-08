#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string s = "";
	object ob,me = this_player();
	//判断身上物品是否超过60件
	/*
	if(me->if_over_load()){
		string tmp = "你的背包已满，无法执行此操作，请返回。\n";       
		tmp+="[返回:look]\n";
		write(tmp);
		return 1;
	}
	*/
	if(arg){
		string name;
		int fee;
		sscanf(arg,"%s %d",name, fee);
		ob=clone(ROOT+"/gamelib/clone/item/"+name);
		//只购买一个
		if(!ob){
			s += "你要购买的物品不存在，请返回。\n";	
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
	
		if(me->if_over_load(ob)){
			s = "你的背包已满，无法执行此操作，请返回。\n";       
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}

		int need_money = fee;
		if(me->pay_money(need_money)==0){
			s += "你身上的钱不够支付费用，请返回。\n";
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		}
		else{
			s += "交易成功！\n你花费"+MUD_MONEYD->query_store_money_cn(need_money)+"\n";
			s += "得到了物品 "+ob->query_name_cn()+"！\n";
			if(ob->is("combine_item"))
				ob->move_player(me->query_name());
			else
				ob->move(me);
			
			string now=ctime(time());
			string tmp = now[0..sizeof(now)-2]+":"+me->name_cn+"("+me->name+")\n";
			tmp += s;
			Stdio.append_file(ROOT+"/log/buy.log",tmp+"\n");
			s+="[返回游戏:look]\n";
			write(s);
		}
	}
	
	return 1;
}


