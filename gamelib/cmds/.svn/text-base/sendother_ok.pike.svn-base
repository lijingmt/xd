#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	string user_name;
	int user_count;
	string goods_id;
	string type;
	object player=this_player();
	object goods;
	if(sscanf(arg,"%s %d %s %s",user_name,user_count,goods_id,type)==4){
		object ob=present(user_name,environment(player));
		if(!ob)
	    		ob=find_player(user_name);
		if(!ob){
			s += "要赠送物品给你的人目前不在线，请返回。\n";
			s += "[返回:look]\n";
			write(s);
			return 1;
		}
		else{
			//goods=present(goods_id,ob,user_count); 
			//查找玩家身上与name同名的非会员物品 added by caijie 080815
			array(object) all_ob = all_inventory(ob);
			foreach(all_ob,object each_ob){
				if(each_ob->query_name()==goods_id&&(!each_ob->query_toVip())){
					goods = each_ob;
					break;
				}
			}
			//add end
			int item_totalnum_now = inventory_item_num(goods_id,ob);
			if(goods){
				int is_send = is_send(goods_id,ob);
				if(goods->equiped){
					s += "该物品正在装备，无法赠送，请返回确认。\n";
					s += "[返回游戏:look]\n";
					write(s);
					return 1;
				}
				else if(!is_send)
				{
					s += "对方没有发送该物品给你，请返回。\n";
					s += "[返回游戏:look]\n";
					write(s);
					return 1;
				}
				else{
					if(type=="yes"){
						//判断身上物品是否超过60件
						if(this_player()->if_over_load(goods)){
							string tmp = "你的背包已装满，无法执行此操作，请返回。\n";       
							tmp+="[返回:look]\n";
							write(tmp);
							return 1;
						}
						tell_object(player,"成功接受物品"+goods->name_cn+"\n");
						tell_object(ob,"物品"+goods->name_cn+"已经成功赠送给"+player->name_cn+"\n");
						string now=ctime(time());
						object env = environment(player);
						int goods_num=1;
						if(goods->is("combine_item"))
							goods_num = goods->amount;
						Stdio.append_file(ROOT+"/log/send.log",now[0..sizeof(now)-2]+":"+ob->name_cn+"("+ob->name+") 在"+env->query_name_cn()+" send ("+goods_num+")"+goods->name_cn+"("+goods->name+") to "+player->name_cn+"("+player->name+")\n");
						if(goods->is("combine_item"))
							goods->move_player(player->query_name());
						else
							goods->move(player);
						s += "[返回游戏:look]\n";
						write(s);
						return 1;
					}
					else{
						tell_object(player,"你拒绝了"+ob->name_cn+"赠送给你的物品"+goods->name_cn+"\n");
						tell_object(ob,player->name_cn+"拒绝接受物品"+goods->name_cn+"\n");
						s += "[返回游戏:look]\n";
						write(s);
						return 1;
					}
				}
			}
			else
				s += "该物品不存在，请返回确认。\n";
		}
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
int inventory_item_num(string item_name,void|object looker)
{
	int num =0;
	if(!looker)
		looker=this_player();
	array(object) a = all_inventory(looker);                                                                              
	foreach(a,object tmp)
	{
		if(tmp&&tmp->query_name()==item_name)
			num++;
	}
	return num;
}
//查询发送者是否发送了某个物品给当前玩家
//在查询完毕后删除发送标识
//返回参数  0:没有发送请求
//          >0: 有发送请求
int is_send(string item_name,object sender)
{
	object me = this_player();
	if(!sender["/plus/sendrecd"])	
		return 0;
	if(!sender["/plus/sendrecd"][me->name])
		return 0;
	if(!sender["/plus/sendrecd"][me->name][item_name])
	{
		m_delete(sender["/plus/sendrecd"][me->name],item_name);		
		return 0;
	}
	else
	{
		int retInt = sender["/plus/sendrecd"][me->name][item_name];	
		sender["/plus/sendrecd"][me->name][item_name]--;	
		if(!sender["/plus/sendrecd"][me->name][item_name])
			m_delete(sender["/plus/sendrecd"][me->name],item_name);		
		return retInt;
	}
}
