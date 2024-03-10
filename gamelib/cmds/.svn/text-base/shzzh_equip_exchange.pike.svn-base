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
	string s = "国庆限量版饰品，先到先得～\n\n";
	string s_log = ""; 
	object me=this_player();
	string type = "";
	string item_name = "";
	int need_huiji = 0;
	int need_money = 0;
	string need_name = "";
	int flag = 0;
	sscanf(arg,"%s %s %d %s %d",type,item_name,need_huiji,need_name,flag);
	if(flag == 0){
		object item;
		mixed err = catch{
			item = (object)(ITEM_PATH+item_name);
		};
		if(!err && item){
			s += item->query_short()+"\n";
			s += item->query_picture_url()+"\n"+item->query_desc()+"\n";
			if(!item->is_combine_item())
				s += item->query_content()+"\n";
			if(need_huiji > 0){
				if(type=="9ji")
					s += "需要：一级十字章x"+need_huiji+"\n";
				if(type=="19ji")
					s += "需要：二级十字章x"+need_huiji+"\n";
				if(type=="29ji")
					s += "需要：三级十字章x"+need_huiji+"\n";
				if(type=="39ji")
					s += "需要：四级十字章x"+need_huiji+"\n";
				if(type=="49ji")
					s += "需要：五级十字章x"+need_huiji+"\n";
				if(type=="59ji")
					s += "需要：六级十字章x"+need_huiji+"\n";
				if(type=="69ji")
					s += "需要：七级十字章x"+need_huiji+"\n";
			}
			s += "[换取:shzzh_equip_exchange "+type+" "+item_name+" "+need_huiji+" "+need_name+" 1]\n";
		}
	}
	else if(flag >= 1){
		//用徽记换取的，不用判断玩家是否在排名第一的帮派，凡是够徽记就能换取
		//判断是否够徽记购买
		int have_huiji = 0;//玩家身上拥有的徽记个数
		int spec_have = 0; 
		array(object) all_obj = all_inventory(me);
		foreach(all_obj,object ob){
			if(ob->is_combine_item() && ob->query_name() == need_name){
				have_huiji += ob->amount;
			}
		}
		if(have_huiji < need_huiji){
			s += "换取失败！你身上没有足够的十字章\n";
		}
		else if(me->if_over_easy_load()){
			s += "换取失败！你的随身物品已满\n";
		}
		else{
			//满足换取的条件
			object item;
			mixed err = catch{
				item = clone(ITEM_PATH+item_name);
			};
			if(!err && item){
				//删除玩家身上相应的徽记
				if(need_huiji)
					me->remove_combine_item(need_name,need_huiji);
				//删除金钱
				s += "换取成功！你获得了"+item->query_short()+"\n";
				s_log = me->query_name_cn()+"("+me->query_name()+") 花费"+need_huiji+need_name+"个X级十字章，获得了"+item->query_short();
				if(item->is("combine_item"))
					item->move_player(me->query_name());
				else
					item->move(me);
				string now=ctime(time());
				Stdio.append_file(ROOT+"/log/bz_equip_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else
				s += "换取失败！这东西似乎有点不对头\n";
		}
	}
	s += "[返回:shzzh_view_equiplist "+type+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
