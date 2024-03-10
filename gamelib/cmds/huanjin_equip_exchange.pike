#include <command.h>                                                                                                      
#include <gamelib/include/gamelib.h>
//此指令实现利用混沌碎片合成【混沌】饰品或者利用血火石换取【狐】武器功能
//arg = type item_name need_hdsuipian|need_xuehuoshi flag
//type = "hundun" "hu"
//item_name 合成或换取的物品名
//need_cailiao 需要的混沌碎片个数或需要的血火石个数
//flag 换取标识 1、换取或者合成   0、查看物品详情

int main(string arg){
	int flag = 0;
	int need_cailiao = 0;//需要混沌碎片或血火石的数量
	string s = "";
	string s_log = "";
	string type = "";
	string item_name = "";
	object me = this_player();
	sscanf(arg,"%s %s %d %d",type,item_name,need_cailiao,flag);
	if(flag == 0){
		object item = (object)(ITEM_PATH + "bossdrop/" + item_name);
		s += item->query_short()+"\n"+item->query_picture_url()+"\n"+item->query_desc()+"\n";
		if(!item->is_combine_item()){
			s += item->query_content()+"\n";
		}
		if(need_cailiao>0){
			if(type == "hundun"){
				 s += "需要：混沌碎片x"+need_cailiao+"\n";
				 s += "[合成:huanjin_equip_exchange.pike "+type+" "+item_name+" "+need_cailiao+" 1]\n";
			}
			else {
				s += "需要：血火石x"+need_cailiao+"\n";
				s += "[换取:huanjin_equip_exchange.pike "+type+" "+item_name+" "+need_cailiao+" 1]\n";
			}
		}
	}
	else if(flag == 1){
		int have_hdsuipian = 0;//玩家身上拥有的混沌碎片的个数
		int have_xuehuoshi = 0;//玩家身上拥有的血火石的个数
		//判断玩家身上是否有足够的混沌碎片或血火石
		array(object) all_ob = all_inventory(me);
		foreach(all_ob,object ob){
			if(ob->is_combine_item() && ob->query_name() == "hundunsuipian"){
				have_hdsuipian += ob->amount;
			}
			if(ob->is_combine_item() && ob->query_name() == "xuehuoshi"){
				have_xuehuoshi += ob->amount;
			}
		}
		if(me->if_over_easy_load()){
			s += "操作失败！您随身的物品已满\n";
		}
		//利用混沌碎片合成【混沌】饰品
		else if(type == "hundun"){
			if(have_hdsuipian<need_cailiao){
				s += "合成失败！您没有足够的混沌碎片\n";
			}
			else {
				object item;
				mixed err = catch{
					item = clone(ITEM_PATH +"bossdrop/"+ item_name);
				};
				if(err){
					s += "这东西好像有点不对头\n";
					s += "[返回:huanjin_view_equiplist "+type+"]\n";
					s += "[返回游戏:look]\n";
					s_log += me->query_name_cn()+"("+me->query_name()+")"+"clone时物品出错";
					write(s);
					string now=ctime(time());
					Stdio.append_file(ROOT+"/log/huanjin_equip_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");   
					return 1;
				}
				me->remove_combine_item("hundunsuipian",need_cailiao);//删除所需物品
				item->move(me);
				s += "物品合成成功！您获得了"+item->query_short()+"\n";
				s_log = me->query_name_cn()+"("+me->query_name()+")"+"花费"+need_cailiao+"个混沌碎片合成"+item->query_short();
				string now=ctime(time());
				Stdio.append_file(ROOT+"/log/huanjin_equip_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
		}
		//利用血火石换取【狐】武器
		else if(type == "hu"){
			if(have_xuehuoshi<need_cailiao){
				s += "换取失败！您没有足够的血火石\n";
			}
			else {
				object item;
				mixed err = catch{
					item = clone(ITEM_PATH +"bossdrop/"+ item_name);
				};
				if(err){
					s += "这东西好像有点不对头\n";
					s += "[返回:huanjin_view_equiplist "+type+"]\n";
					s += "[返回游戏:look]\n";
					s_log += me->query_name_cn()+"("+me->query_name()+")"+"clone时物品出错";
					write(s);
					string now=ctime(time());
					Stdio.append_file(ROOT+"/log/huanjin_equip_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");   
					return 1;
				}
				me->remove_combine_item("xuehuoshi",need_cailiao);//删除所需的血火石
				item->move(me);
				s += "换取成功！您获得了"+item->query_short()+"\n";
				s_log = me->query_name_cn()+"("+me->query_name()+")"+"花费"+need_cailiao+"个血火石换取"+item->query_short();
				string now=ctime(time());
				Stdio.append_file(ROOT+"/log/huanjin_equip_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
		}
		else s += "操作失败！这东西似乎有点不对头\n";
	}
	s += "[返回:huanjin_view_equiplist "+type+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
