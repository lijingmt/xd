#include <command.h>
#include <gamelib/include/gamelib.h>
#define MAX_AMOUNT 9999999
//指令格式trade [sb] [sth] with silver [...]
int main(string arg)
{	
	string user_name=arg;
	string tmp;
	string money_type="silver";
	int user_count,amount;
	object player=this_player();
	object goods;
	sscanf(arg,"%s %d",user_name,user_count);
	object ob=present(user_name,environment(player),user_count);
	if(!ob)
	    ob=find_player(user_name);
	if(!ob){
		player->write_view(WAP_VIEWD["/trade_nobody"]);
		return 1;
	}
	string s = "";
	if(sscanf(arg,"%s %d %s",user_name,user_count,s)!=3 || !s){
		arg="trade_daoju "+arg+" "+user_count;
		//select a item to exchange
		//这个地方视图调用的是gamelib/master.pike下的
		player->write_view(WAP_VIEWD["/trade_goods_daoju"],ob,0,arg);
		return 1;
	}
	string goods_name;
	int goods_count=0;
	sscanf(s,"%s %d",goods_name,goods_count);
	if(sscanf(arg,"%s buy agree",tmp)==1 || sscanf(arg,"%s buy cancel",tmp)==1) 
	{
		//goods=present(goods_name,ob,goods_count); //[sb] is seller
		//查找玩家身上与name同名的非会员物品 added by caijie 080815
		array(object) all_ob = all_inventory(ob);
		foreach(all_ob,object each_ob){
			if(each_ob->query_name()==goods_name&&(!each_ob->query_toVip())){
				goods = each_ob;
				break;
			}
		}
		//add end
	}
	else {
	        //goods=present(goods_name,player,goods_count); //[sb] is purchaser
		//查找玩家身上与name同名的非会员物品 added by caijie 080815
		array(object) all_ob = all_inventory(player);
		foreach(all_ob,object each_ob){
			if(each_ob->query_name()==goods_name&&(!each_ob->query_toVip())){
				goods = each_ob;
				break;
			}
		}
		//add end
	}
	if(!goods){
		player->write_view(WAP_VIEWD["/trade_fail_nogoods"]);
		return 1;
	}
	if(goods->equiped){
		player->write_view(WAP_VIEWD["/trade_fail_equip"]);//equiped items cannot exchange
		return 1;
	}
	if(goods->query_item_type()=="yushi"&&player->query_level()<=8){
		player->write_view(WAP_VIEWD["/emote"],0,0,"8级以下的玩家不能交易玉石\n");
		return 1;
	}
	if(sscanf(s,"%s %d with silver %d",goods_name,goods_count,amount)!=3){
		string tmp = "你现在和 "+ob->name_cn+" 交易\n";
		tmp += "请输入价钱(必须用银作单位):\n";
		tmp += "[int:trade "+ob->query_name()+" "+user_count+" "+goods_name+" "+goods_count+" with silver ...]\n";
		tmp += "[返回:trade "+ob->query_name()+"]\n";
		tmp += "[返回游戏:look]\n";
		write(tmp+"\n");
		return 1;
	}
	if(amount<=0 || amount>=MAX_AMOUNT){
		player->write_view(WAP_VIEWD["/trade_fail_money"]);
		return 1;
	}
	string flag;
	sscanf(s,"%s %d with silver %d %s",goods_name,goods_count,amount,flag);
	if(amount<=0 || amount>=MAX_AMOUNT){
		player->write_view(WAP_VIEWD["/trade_fail_money"]);
		return 1;
	}
	if(!flag){
		//give the seller affirmation info.
		player->write_view(WAP_VIEWD["/trade_affirm"],0,0,({goods->name_cn,MUD_MONEYD->query_store_money_cn(amount),money_type,ob->name_cn,arg}));
		return 1;
	}
	if(flag=="sell agree"){
		//seller agree
		arg="trade "+ob->name+" "+user_count+" "+goods_name+" "+goods_count+" with silver "+amount;
		player->reset_view();
		player->write_view(WAP_VIEWD["/trade_wait"],ob);
		arg="trade "+player->name+" "+user_count+" "+goods_name+" "+goods_count+" with silver "+amount;
		string t_desc="";
		if(goods->query_item_canTrade()==1){
			if(goods->query_item_type()=="weapon"||goods->query_item_type()=="single_weapon"||goods->query_item_type()=="double_weapon"||goods->query_item_type()=="armor"||goods->query_item_type()=="decorate"||goods->query_item_type()=="jewelry")
				t_desc+=goods->query_content();
			else
				t_desc+=goods->query_desc();
			tell_object(ob,player->name_cn+"想卖给你"+goods->query_short()+"：\n"+t_desc+"\n出价："+MUD_MONEYD->query_store_money_cn(amount)+"\n"+"[确认交易:"+arg+" buy agree]\n[取消交易:"+arg+" buy cancel]\n");
		}
		else{
			string tmp = "该物品不能交易，请返回。\n";
			player->write_view(WAP_VIEWD["/emote"],0,0,tmp);
			return 1;
		}
		return 1;
	}
	if(flag=="sell cancel"){
		//seller disagree
		player->pop_view();
		player->pop_view();
		player->pop_view();
	    player->write_view_tmp(WAP_VIEWD["/trade_cancel"]);
		return 1;
	}
	if(flag=="buy agree"){
		//the purchaser agree this
		player->pop_view();
		if(player->trade_money_judge(amount)==0){
			player->write_view(WAP_VIEWD["/trade_fail_afford"]);
			tell_object(ob,"对方没有足够的金钱，交易失败，请返回。\n");
			return 1;
		}
		if(!goods){
			player->pop_view();
			player->write_view(WAP_VIEWD["/trade_fail_nogoods"]);
			tell_object(ob,"交易物品不在你身上，请返回。\n");
			return 1;
		}
		if(goods->equiped){
			player->write_view(WAP_VIEWD["/trade_fail_equip"]);
			tell_object(ob,"请先卸载身上要交易的物品!\n");
			return 1;
		}
		//判断身上物品是否超过60件
		if(this_player()->if_over_load(goods)){
			string tmp = "你的背包已满，无法执行此操作，请返回。\n";       
			tmp+="[返回:look]\n";
			write(tmp);
			return 1;
		}
		if(player->pay_money(amount)==0){
			tell_object(player,"你没有足够的金钱，交易失败，请返回。\n");
			tell_object(ob,"对方没有足够的金钱，交易失败，请返回。\n");
			return 1;
		}
		else{
			player->write_view(WAP_VIEWD["/trade_success"]);
			tell_object(ob,"交易成功!\n");
			int goods_num=1;
			if(goods->is("combine_item")){
				goods_num = goods->amount;
				goods->move_player(player->query_name());
			}
			else
				goods->move(player);
			ob->add_money(amount);
			string now=ctime(time());
			object env = environment(player);
			Stdio.append_file(ROOT+"/log/trade.log",now[0..sizeof(now)-2]+":"+ob->name_cn+"("+ob->name+") 在"+env->query_name_cn()+" sell ("+goods_num+")"+goods_name+" to "+player->name_cn+"("+player->name+") with "+amount+" silver\n");
			return 1;
		}
	}
	if(flag=="buy cancel"){
		player->write_view(WAP_VIEWD["/trade_cancel"]);		
		tell_object(ob,"对方拒绝了本次交易!\n");
		return 1;
	}
	return 1;
}
