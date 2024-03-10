#include <command.h>
#include <gamelib/include/gamelib.h>

#define PATH ROOT "/gamelib/clone/item/bossdrop/"

/*******************************************************************************
 *此指令用火月签固定换取物品模块
 *arg为空：列出火月签可换取的物品清单
 *arg = item_name,exchange_count
 *exchange_count 输入的换取物品的数量
 *********************************************************************************/

int main(string arg){
	object me = this_player();
	object item;
	string item_name = "";
	string s = "";
	string s_log = ""; 
	//int count = 0;
	int exchange_count = 0;
	int have_huoyueqian = 0;
	array(object) all_ob =all_inventory(me);
	foreach(all_ob,object ob){
		if(ob->is_combine_item()&&ob->query_name()=="huoyueqian"){
			have_huoyueqian += ob->amount;
		}
	}
	if(!have_huoyueqian){
		s += "火月签可以换取霸王徽记、血火石或者混沌碎片。\n";
		s += "但是您现在并没有火月签。\n";
		s += "先去获得火月签再过来吧:）\n";
		s += "火月签可以通过神州行50元捐赠获得\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(!arg){
		s += "火月签可换取的物品列表:\n";
		s += "--------\n";
		s += "[霸王徽记:hyq_exchange bawanghuiji 0](x"+have_huoyueqian+")\n";
		s += "[血火石:hyq_exchange xuehuoshi 0](x"+have_huoyueqian+")\n";
		s += "[混沌碎片:hyq_exchange hundunsuipian 0](x"+have_huoyueqian+")\n";
		s += "\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(arg){
		sscanf(arg,"%s %d",item_name,exchange_count);
		//werror("------name------------"+item_name+"-----------\n");
		//werror("------name1------------"+exchange_count+"-----------\n");
		//sscanf(exchange_count,"no=%d",count);
		if(!item_name){
			s += "这东西好像有点不对头。\n";
			s += "[继续换取:hyq_exchange]\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
		if(!exchange_count){
			object item_ob = (object)(PATH+item_name);
			string item_name_cn = item_ob->query_name_cn();
			s += "换取"+item_name_cn+"需要一支火月签。\n";
			s += item_describe(item_name);
			s += "您目前共有"+have_huoyueqian+"支火月签可换取\n";
			s += "请输入想要换取的数量(1-20):\n";
			//s += "[int no:...]\n";
			s += "[换取:hyq_exchange "+item_name+" ...]\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		else{
			object item_ob = (object)(PATH+item_name);
			string item_name_cn = item_ob->query_name_cn();
			if(exchange_count>20||exchange_count<0){
				s += "您输入的数量不正确，换取数量必须大于0小于等于20\n";
				s += "[继续换取:hyq_exchange]\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			if(exchange_count>have_huoyueqian){
				s += "您没有足够的火月签，你最多可换"+have_huoyueqian+item_name_cn+"\n";
				s += "[继续换取:hyq_exchange]\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			//满足条件
			mixed err = catch{
				item = clone(PATH+item_name);
			};
			if(!err&&item){
				if(me->if_over_load(item)){
					s += "你随身物品已满，无法存放更多的东西。\n";
				}
				else{
					item->amount = exchange_count;
					item->move(me);
					me->remove_combine_item("huoyueqian",exchange_count);
					s += "换取成功，您获得了"+exchange_count+item_name_cn+"。\n";
					s_log += me->query_name_cn()+"("+me->query_name()+")"+"花了"+exchange_count+"支火月签换取"+exchange_count+item_name_cn+"\n";
					string now=ctime(time());
					Stdio.append_file(ROOT+"/log/hyq_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
				}
			}
		}
	}
	s += "[返回:hyq_exchange]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}


string item_describe(string item_name){
	string s = "";
	if(item_name=="bawanghuiji"){
		s += "凭借此物品可以换购霸王堡欢购场的物品。\n";
	}
	else if(item_name=="xuehuoshi"){
		s += "该物品可换取55级新幻境【狐】武器。\n";
	}
	else if(item_name=="hundunsuipian"){
		s += "该物品可换取55级新幻境【混沌】饰品。\n";
	}
	return s;
}
