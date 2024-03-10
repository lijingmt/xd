#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s,name=arg;
	int fee,count=0;
	object me = this_player();
	if(!arg){
		mapping(string:int) name_count=([]);
		s="请选择需要修理的物品。\n";
		string s2 = "";
		object tmp;
		array arr = all_inventory(me);
		foreach(arr,tmp){
			if(tmp->is("equip")&&(tmp->query_item_type()=="weapon"||tmp->query_item_type()=="single_weapon"||tmp->query_item_type()=="double_weapon"||tmp->query_item_type()=="armor")){
				int r_m = 0;
				if(tmp->item_cur_dura != tmp->item_dura){
					float a = (float)tmp->query_item_canLevel();//1级;
					float b = (float)(tmp->item_dura-tmp->item_cur_dura)/(float)(tmp->item_dura);//235/280;
					float need = 0.00;
					need = (a*50.00)/10.00*b;
					r_m = (int)need;
					if(r_m==0)
						r_m = 1;
				}
				string s_m = "";
				if(r_m>0){
					s_m += MUD_MONEYD->query_store_money_cn(r_m);
					s2+="["+tmp->name_cn+":repair "+tmp->name+" "+name_count[tmp->name]+"]("+tmp->item_cur_dura+"/"+tmp->item_dura+")("+s_m+")\n";
				}
				name_count[tmp->name]++;
			}
		}
		if(s2&&sizeof(s2))
			s += s2;
		else
			s += "暂时没有损坏的装备可供修理，请返回。\n";
		write(s);
		write("[返回游戏:look]");
		//me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	s = "";
	sscanf(arg,"%s %d",name,count);
	object ob = present(name,me,count);
	if(ob->is("equip")&&(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor")){
		if(!ob){
			s+="请确认你身上有这样的物品。\n";
			write("[返回:repair]\n");
			write("[返回游戏:look]\n");
			return 1;
		}
		if(ob->item_cur_dura == ob->item_dura){
			s+="请确认这件物品真的需要修理么？它根本没有磨损过。\n";
			write("[返回:repair]\n");
			write("[返回游戏:look]\n");
			return 1;
		}
		if(ob->item_cur_dura<=0)
			s += "如果物品当前耐久为零，即使装备上，也不能获取相应属性，所以，如果装备耐久降低的话，就请尽快修理。\n";
		float a = (float)ob->query_item_canLevel();
		float b = (float)(ob->item_dura-ob->item_cur_dura)/(float)(ob->item_dura);
		float need = 0.00;
		need = (a*50.00)/10.00*b;
		fee = (int)need;
		if(fee==0)
			fee = 1;
		s += "此次修理共需费用："+MUD_MONEYD->query_store_money_cn(fee)+"\n";
		if(me->pay_money(fee)==0)
			s += "你身上的钱不够支付费用，请返回。\n";
		else{
			ob->item_cur_dura = ob->item_dura;	
			s+="修理结束，该物品已经恢复了耐久度。\n";
		}
	}
	else
		s += "该物品无法修理！\n";
	write(s);
	write("[返回:repair]\n");
	write("[返回游戏:look]\n");
	return 1;
}
