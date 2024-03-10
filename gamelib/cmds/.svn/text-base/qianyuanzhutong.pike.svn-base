#include <command.h>
#include <gamelib/include/gamelib.h>


//此指令用于实现"签缘竹筒"功能，即玩家放入2支火月签，会随机的到霸王徽记、血火石或者混沌碎片，或者什么也没有

int main(string arg){
	object me = this_player();
	object item;
	string s = "";
	string s_log = "";//打log
	int have_huoyueqian = 0;//记录玩家拥有的火月签的数量
	array(object) all_ob = all_inventory(me);
	foreach(all_ob,object ob){
		if(ob->is_combine_item()&&ob->query_name()=="huoyueqian"){
			have_huoyueqian += ob->amount;
		}
	}
	if(have_huoyueqian<2){
		s += "需要火月签2支，您袋中的火月签不够。\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(!arg){
		s += "您需要放入两支火月签，有可能会获得霸王徽记、血火石、混沌碎片、碎玉中的某一种3个，但也有可能什么也得不到，您确定要放入吗？\n";
		s += "[确定:qianyuanzhutong yes]  [放弃:qianyuanzhutong no]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(arg=="yes"){
		int ran_num = random(100);//从1-100随机分配一个整数
		me->remove_combine_item("huoyueqian",2);
		if(ran_num>=1&&ran_num<=15){
			mixed err = catch{
				item = clone(ITEM_PATH + "bossdrop/bawanghuiji");
			};
			if(!err&&item){
				item->amount = 3;
				item->move(me);
			}
			s += "运气不错哦，您获得了3霸王徽记，该物品可以换购霸王堡欢购场的物品。\n";
			s_log += me->query_name_cn()+"("+me->query_name()+")把2支火月签放入签缘竹筒获得3霸王徽记.\n";
		}
		else if(ran_num>15&&ran_num<=30){
			mixed err = catch{
				item = clone(ITEM_PATH + "bossdrop/xuehuoshi");
			};
			if(!err&&item){
				item->amount = 3;
				item->move(me);
			}
			s += "运气不错哦，您获得了3血火石，该物品可以换取55级新幻境【狐】武器。\n";
			s_log += me->query_name_cn()+"("+me->query_name()+")把2支火月签放入签缘竹筒获得3血火石.\n";
		}
		else if(ran_num>30&&ran_num<=45){
			mixed err = catch{
				item = clone(ITEM_PATH + "bossdrop/hundunsuipian");
			};
			if(!err&&item){
				item->amount = 3;
				item->move(me);
			}
			s += "运气不错哦，您获得了3混沌碎片，该物品可以换换取55级新幻境【混沌】饰品。\n";
			s_log += me->query_name_cn()+"("+me->query_name()+")把2支火月签放入签缘竹筒获得3混沌碎片.\n";
		}
		else if(ran_num>45&&ran_num<=70){
			mixed err = catch{
				item = clone(ITEM_PATH + "yushi/suiyu");
			};
			if(!err&&item){
				item->amount = 3;
				item->move(me);
			}
			s += "运气不错哦，您获得了3碎玉\n";
			s_log += me->query_name_cn()+"("+me->query_name()+")把2支火月签放入签缘竹筒获得3碎玉.\n";
		}
		else {
			s += "真遗憾，竹筒里空空的什么也没有。\n";
			s_log += me->query_name_cn()+"("+me->query_name()+")把2支火月签放入签缘竹筒什么也没得到.\n";
		}
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/hyq_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(arg=="no"){
		s += "那你再考虑一下吧！\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}

