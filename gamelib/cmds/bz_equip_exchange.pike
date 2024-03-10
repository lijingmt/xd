#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令换取帮战中可用霸王徽记换取的装备
//arg = type item_name need_huiji need_money flag
//   type="weapon" , "buyi"，"qingjia" or "zhongkai" "spec"
//   item_name 换取的物品名
//   need_huiji 需要的徽记个数
//   need_money 需要的金钱数
//   flag  购买标识，1为徽记确认购买，2为G币确认购买，0为查看物品详情
int main(string arg)
{
	string s = "这里的东西只属于霸者\n";
	string s_log = ""; 
	object me=this_player();
	string type = "";
	string item_name = "";
	string mid_path = "";
	int need_huiji = 0;
	int need_money = 0;
	int flag = 0;
	sscanf(arg,"%s %s %d %d %d",type,item_name,need_huiji,need_money,flag);
	if(type != "spec")
		mid_path = "bossdrop/";
	else
		mid_path = "liandan/";
	if(flag == 0){
		object item;
		mixed err = catch{
			item = (object)(ITEM_PATH+mid_path+item_name);
		};
		if(!err && item){
			s += item->query_short()+"\n";
			s += item->query_picture_url()+"\n"+item->query_desc()+"\n";
			if(!item->is_combine_item())
				s += item->query_content()+"\n";
			string s_money = MUD_MONEYD->query_other_money_cn(need_money);
			if(type != "spec"){
				if(need_huiji > 0)
					s += "需要：霸王徽记x"+need_huiji+"\n";
				if(need_money > 0)
					s += "需要："+s_money+"\n";
				s += "[换取:bz_equip_exchange "+type+" "+item_name+" "+need_huiji+" "+need_money+" 1]\n";
			}
			else if(type == "spec"){
				s += "[徽记换取:bz_equip_exchange "+type+" "+item_name+" "+need_huiji+" 0 1](霸王徽记x"+need_huiji+")\n";
				s += "[金币购买:bz_equip_exchange "+type+" "+item_name+" 0 "+need_money+" 2]("+s_money+")\n";
			}
		}
	}
	else if(flag >= 1){
		//用徽记换取的，不用判断玩家是否在排名第一的帮派，凡是够徽记就能换取
		//判断是否够徽记购买
		int have_huiji = 0;//玩家身上拥有的徽记个数
		int spec_have = 0; 
		array(object) all_obj = all_inventory(me);
		foreach(all_obj,object ob){
			if(ob->is_combine_item() && ob->query_name() == "bawanghuiji"){
				have_huiji += ob->amount;
			}
			if(ob->is_combine_item() && ob->query_for_material() == "bawang_spec"){
				spec_have = 1;
			}
		}
		if(flag == 2&&(me->bangid != BANGZHAND->query_top_bang(1)||!BANGZHAND->query_open_fg())){
			s += "购买失败！暂未发榜或者你的帮派不是排行第一\n";
		}
		else if(type == "spec" && spec_have){
			s += "购买失败！你上次购买的还没用完，无法获得更多\n";
		}
		else if(have_huiji < need_huiji){
			s += "换取失败！你身上没有足够的徽记\n";
		}
		else if(me->query_account() < need_money){
			s += "换取失败！你身上没有足够的金钱\n";
		}
		else if(me->if_over_easy_load()){
			s += "换取失败！你的随身物品已满\n";
		}
		else if(type == "spec" &&me->get_once_day["bawang_spec"]==1){
			s += "换取失败！一天只能换取一次\n";
		}
		else{
			//满足换取的条件
			object item;
			mixed err = catch{
				item = clone(ITEM_PATH+mid_path+item_name);
			};
			if(!err && item){
				//删除玩家身上相应的徽记
				if(need_huiji)
					me->remove_combine_item("bawanghuiji",need_huiji);
				//删除金钱
				if(need_money)
					me->del_account(need_money);
				if(item->is("combine_item")){
					item->amount = 2;
					me->get_once_day["bawang_spec"] = 1;
				}
				s += "交易成功！你获得了"+item->query_short()+"\n";
				s_log = me->query_name_cn()+"("+me->query_name()+") 花费"+need_huiji+"个霸王徽记，"+need_money+"金钱，获得了"+item->query_short();
				if(item->is("combine_item"))
					item->move_player(me->query_name());
				else
					item->move(me);
				string now=ctime(time());
				Stdio.append_file(ROOT+"/log/bz_equip_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else
				s += "交易失败！这东西似乎有点不对头\n";
		}
	}
	s += "[返回:bz_view_equiplist "+type+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
